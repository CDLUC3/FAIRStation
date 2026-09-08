require "json"
require "faraday"

class HttpClient
  class Error < StandardError; end

  class ResponseError < Error
    attr_reader :status

    def initialize(status)
      @status = status
      super("HTTP request failed with status #{status}")
    end
  end

  class InvalidJson < Error; end

  def initialize(base_url:, connection: nil)
    @base_url = base_url
    @connection = connection || default_connection
  end

  def get_json(path:, headers: {})
    response = connection.get do |request|
      request.url URI.join(normalized_base_url, path).to_s
      request.headers.update(headers)
    end
    raise ResponseError, response.status unless response.status.between?(200, 299)

    JSON.parse(response.body)
  rescue JSON::ParserError => error
    raise InvalidJson, "HTTP response contained invalid JSON: #{error.message}"
  end

  private

  attr_reader :base_url, :connection

  def default_connection
    Faraday.new do |faraday|
      faraday.options.open_timeout = 5
      faraday.options.timeout = 30
    end
  end

  def normalized_base_url
    base_url.end_with?("/") ? base_url : "#{base_url}/"
  end
end
