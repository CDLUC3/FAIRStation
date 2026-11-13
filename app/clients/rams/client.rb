require "net/http"
require "json"

module Rams
  # Read-only RAMS transport. Never follows redirects with the bearer token.
  class Client
    BASE_URL = "https://rams.ucnature.org/api/v1/"

    def initialize(token:, transport: Net::HTTP)
      raise Error, "RAMS token is missing" if token.blank?
      @token, @transport = token, transport
    end

    def collection(resource, **filters)
      records = []
      expected = nil
      page = 1
      loop do
        payload = get(resource, **filters, page: page, per_page: 100)
        meta = payload.fetch("meta")
        unless meta.is_a?(Hash) && payload["data"].is_a?(Array)
          raise Error, "Invalid RAMS collection for #{resource}"
        end
        signature = meta.values_at("total_count", "total_pages", "per_page")
        unless meta["page"] == page && signature.all? { |n| n.is_a?(Integer) && n >= 0 } && meta["per_page"].positive?
          raise Error, "Invalid RAMS pagination for #{resource}"
        end
        expected ||= signature
        raise Error, "RAMS counts changed during #{resource} pull; retry the full run" unless expected == signature
        records.concat(payload.fetch("data"))
        break if page >= meta.fetch("total_pages")
        page += 1
      end
      ids = records.map { |row| row.fetch("id") }
      unless records.size == expected.first && ids.uniq.size == ids.size
        raise Error, "RAMS count/duplicate mismatch for #{resource}"
      end
      { "data" => records, "total_count" => expected.first }
    rescue KeyError, TypeError
      raise Error, "Invalid RAMS collection for #{resource}"
    end

    def record(resource, id)
      get("#{resource}/#{Integer(id)}").fetch("data")
    end

    private

    def get(path, **query)
      uri = URI.join(BASE_URL, path)
      uri.query = URI.encode_www_form(query) if query.any?
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["Accept"] = "application/json"
      request["User-Agent"] = "FAIRStation/1.0"
      response = @transport.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
        http.request(request)
      end
      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "RAMS HTTP #{response.code} for #{path}; full run stopped (Retry-After: #{response['Retry-After'] || 'none'})"
      end
      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Error, "Invalid RAMS JSON for #{path}"
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError
      raise Error, "RAMS connection failed for #{path}; full run stopped"
    end
  end
end
