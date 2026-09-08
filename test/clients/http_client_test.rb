require "test_helper"

class HttpClientTest < ActiveSupport::TestCase
  test "gets and parses JSON without source-specific behavior" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/records/123") do |environment|
        assert_equal "Bearer secret", environment.request_headers.fetch("Authorization")
        [ 200, { "Content-Type" => "application/json" }, '{"id":123}' ]
      end
    end
    client = HttpClient.new(base_url: "https://source.example/", connection: faraday_connection(stubs))

    result = client.get_json(path: "records/123", headers: { "Authorization" => "Bearer secret" })

    assert_equal({ "id" => 123 }, result)
    stubs.verify_stubbed_calls
  end

  test "raises a generic response error" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/missing") { [ 404, {}, "" ] }
    end
    error = assert_raises(HttpClient::ResponseError) do
      HttpClient.new(
        base_url: "https://source.example",
        connection: faraday_connection(stubs)
      ).get_json(path: "missing")
    end

    assert_equal 404, error.status
    stubs.verify_stubbed_calls
  end

  private

  def faraday_connection(stubs)
    Faraday.new do |faraday|
      faraday.adapter :test, stubs
    end
  end
end
