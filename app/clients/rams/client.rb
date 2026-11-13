require "net/http"
require "json"

module Rams
  # Read-only RAMS transport. Never follows redirects with the bearer token.
  class Client
    def initialize(token:, transport: Net::HTTP, configuration: Configuration.load)
      raise Error, "RAMS token is missing" if token.blank?
      @token, @transport, @configuration = token, transport, configuration
    end

    def collection(resource, **filters)
      first = page(resource, number: 1, **filters)
      remaining = (2..first.total_pages).map do |number|
        page(resource, number: number, **filters).tap { |other| first.verify_consistency!(other, resource: resource) }
      end
      records = [ first, *remaining ].flat_map(&:records)
      verify_records!(records, total: first.total_count, resource: resource)
      { "data" => records, "total_count" => first.total_count }
    end

    def record(resource, id)
      get("#{resource}/#{Integer(id)}").fetch("data")
    end

    private

    def page(resource, number:, **filters)
      Page.parse(get(resource, **filters, page: number, per_page: 100), number: number, resource: resource)
    end

    def verify_records!(records, total:, resource:)
      ids = records.map { |row| row.fetch("id") }
      unless records.size == total && ids.uniq.size == ids.size
        raise Error, "RAMS count/duplicate mismatch for #{resource}"
      end
    rescue KeyError, TypeError, NoMethodError
      raise Error, "Invalid RAMS collection for #{resource}"
    end

    def get(path, **query)
      query_path = query.empty? ? path : "#{path}?#{URI.encode_www_form(query)}"
      response = request(URI.join(@configuration.base_url, query_path))
      verify_response!(response, path)
      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Error, "Invalid RAMS JSON for #{path}"
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError
      raise Error, "RAMS connection failed for #{path}; full run stopped"
    end

    def request(uri)
      request = Net::HTTP::Get.new(uri, "Authorization" => "Bearer #{@token}",
        "Accept" => "application/json", "User-Agent" => "FAIRStation/1.0")
      @transport.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) { |http| http.request(request) }
    end

    def verify_response!(response, path)
      return if response.is_a?(Net::HTTPSuccess)
      raise Error, "RAMS HTTP #{response.code} for #{path}; full run stopped (Retry-After: #{response['Retry-After'] || 'none'})"
    end
  end
end
