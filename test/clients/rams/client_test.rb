require "test_helper"

class Rams::ClientTest < ActiveSupport::TestCase
  class Transport
    attr_reader :requests

    def initialize(responses)
      @responses, @requests = responses, []
    end

    def start(*args, **options)
      raise "TLS required" unless options[:use_ssl]
      yield self
    end

    def request(request)
      @requests << request
      @responses.shift || raise("Unexpected HTTP request")
    end
  end

  def page(number, ids, total: 2)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:body) do
      { data: ids.map { |id| { id: id } }, meta: { page: number, per_page: 1, total_pages: 2, total_count: total } }.to_json
    end
    response
  end

  test "paginates using metadata and authenticates read-only HTTPS requests" do
    transport = Transport.new([ page(1, [ 27 ]), page(2, [ 28 ]) ])
    rows = Rams::Client.new(token: "test-secret", transport: transport).collection("projects", reserve_id: 27)
    assert_equal [ 27, 28 ], rows.fetch("data").map { |row| row.fetch("id") }
    assert_equal 2, rows.fetch("total_count")
    transport.requests.each_with_index do |request, i|
      assert_equal "GET", request.method
      assert_equal "Bearer test-secret", request["Authorization"]
      assert_equal "FAIRStation/1.0", request["User-Agent"]
      assert_includes request.path, "reserve_id=27"
      assert_includes request.path, "page=#{i + 1}"
      assert_not_includes request.path, "updated_since"
    end
  end

  test "rejects duplicate IDs, incomplete pages and counts changing mid-pull" do
    [ [ page(1, [ 27 ]), page(2, [ 27 ]) ],
      [ page(1, [ 27 ]), page(2, []) ],
      [ page(1, [ 27 ]), page(2, [ 28 ], total: 3) ] ].each do |responses|
      assert_raises(Rams::Error) do
        Rams::Client.new(token: "test-secret", transport: Transport.new(responses)).collection("projects")
      end
    end
  end

  test "does not follow redirects or treat auth and rate limit failures as empty collections" do
    { Net::HTTPFound => "302", Net::HTTPUnauthorized => "401", Net::HTTPTooManyRequests => "429", Net::HTTPInternalServerError => "500" }.each do |type, code|
      response = type.new("1.1", code, "error")
      response["Retry-After"] = "60"
      transport = Transport.new([ response ])
      error = assert_raises(Rams::Error) do
        Rams::Client.new(token: "test-secret", transport: transport).collection("reserves")
      end
      assert_not_includes error.message, "test-secret"
      assert_equal 1, transport.requests.size
    end
  end

  test "empty collections stop after the first page" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:body) do
      { data: [], meta: { page: 1, per_page: 100, total_pages: 0, total_count: 0 } }.to_json
    end
    transport = Transport.new([ response ])
    assert_equal({ "data" => [], "total_count" => 0 }, Rams::Client.new(token: "test-secret", transport: transport).collection("institutions"))
    assert_equal 1, transport.requests.size
  end

  test "rejects malformed records and pagination metadata" do
    [ { data: nil, meta: {} },
      { data: [ nil ], meta: { page: 1, per_page: 100, total_pages: 1, total_count: 1 } },
      { data: [], meta: { page: 1, per_page: 0, total_pages: 0, total_count: 0 } } ].each do |payload|
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.define_singleton_method(:body) { payload.to_json }
      assert_raises(Rams::Error) do
        Rams::Client.new(token: "test-secret", transport: Transport.new([ response ])).collection("projects")
      end
    end
  end

  test "fails on invalid JSON without exposing response content" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:body) { "invalid secret body" }
    error = assert_raises(Rams::Error) do
      Rams::Client.new(token: "test-secret", transport: Transport.new([ response ])).collection("reserves")
    end
    assert_not_includes error.message, "secret"
  end
end
