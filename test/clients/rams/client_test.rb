require "test_helper"

class Rams::ClientTest < ActiveSupport::TestCase
  def client_for(responses, resource: "projects")
    @requests = []
    @stubs = Faraday::Adapter::Test::Stubs.new
    responses.each do |response|
      @stubs.get("/api/v1/#{resource}") do |env|
        @requests << env
        raise "Unexpected HTTP request" if @requests.size > responses.size
        response.respond_to?(:call) ? response.call : response
      end
    end
    Rams::Client.new(token: "test-secret", adapter: [ :test, @stubs ])
  end

  def page(number, ids, total: 2)
    payload = { data: ids.map { |id| { id: id } }, meta: { page: number, per_page: 1, total_pages: 2, total_count: total } }
    [ 200, {}, payload.to_json ]
  end

  test "paginates using metadata and authenticates read-only HTTPS requests" do
    client = client_for([ page(1, [ 27 ]), page(2, [ 28 ]) ])
    rows = client.collection("projects", reserve_id: 27)
    assert_equal [ 27, 28 ], rows.fetch("data").map { |row| row.fetch("id") }
    assert_equal 2, rows.fetch("total_count")
    assert_equal 2, @requests.size
    @requests.each_with_index do |request, i|
      assert_equal :get, request.method
      assert_equal "https", request.url.scheme
      assert_equal "/api/v1/projects", request.url.path
      assert_equal "Bearer test-secret", request.request_headers["Authorization"]
      assert_equal "application/json", request.request_headers["Accept"]
      assert_equal "FAIRStation/1.0", request.request_headers["User-Agent"]
      assert_equal "27", request.params.fetch("reserve_id")
      assert_equal (i + 1).to_s, request.params.fetch("page")
      assert_equal "100", request.params.fetch("per_page")
      assert_not_includes request.params, "updated_since"
      assert_equal 10, request.request.open_timeout
      assert_equal 60, request.request.read_timeout
      assert request.ssl.verify
    end
    @stubs.verify_stubbed_calls
  end

  test "rejects duplicate IDs, incomplete pages and counts changing mid-pull" do
    [ [ page(1, [ 27 ]), page(2, [ 27 ]) ],
      [ page(1, [ 27 ]), page(2, []) ],
      [ page(1, [ 27 ]), page(2, [ 28 ], total: 3) ] ].each do |responses|
      assert_raises(Rams::Error) { client_for(responses).collection("projects") }
    end
  end

  test "does not follow redirects or treat auth and rate limit failures as empty collections" do
    [ 302, 401, 429, 500 ].each do |status|
      client = client_for([ [ status, { "Retry-After" => "60", "Location" => "https://elsewhere.example/" }, "private response" ] ], resource: "reserves")
      error = assert_raises(Rams::Error) { client.collection("reserves") }
      assert_includes error.message, "HTTP #{status}"
      assert_includes error.message, "Retry-After: 60"
      assert_not_includes error.message, "test-secret"
      assert_not_includes error.message, "private response"
      assert_equal 1, @requests.size
    end
  end

  test "empty collections stop after the first page" do
    payload = { data: [], meta: { page: 1, per_page: 100, total_pages: 0, total_count: 0 } }
    client = client_for([ [ 200, {}, payload.to_json ] ], resource: "institutions")
    assert_equal({ "data" => [], "total_count" => 0 }, client.collection("institutions"))
    assert_equal 1, @requests.size
  end

  test "rejects malformed records and pagination metadata" do
    [ { data: nil, meta: {} },
      { data: [ nil ], meta: { page: 1, per_page: 100, total_pages: 1, total_count: 1 } },
      { data: [], meta: { page: 1, per_page: 0, total_pages: 0, total_count: 0 } } ].each do |payload|
      assert_raises(Rams::Error) { client_for([ [ 200, {}, payload.to_json ] ]).collection("projects") }
    end
  end

  test "fails on invalid JSON without exposing response content" do
    error = assert_raises(Rams::Error) do
      client_for([ [ 200, {}, "invalid secret body" ] ], resource: "reserves").collection("reserves")
    end
    assert_not_includes error.message, "secret"
  end

  test "connection, timeout and TLS failures stop without retrying or exposing transport details" do
    [ Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::SSLError ].each do |type|
      failure = -> { raise type, "private transport details test-secret" }
      client = client_for([ failure ], resource: "reserves")
      error = assert_raises(Rams::Error) { client.collection("reserves") }
      assert_includes error.message, "connection failed"
      assert_not_includes error.message, "private transport details"
      assert_not_includes error.message, "test-secret"
      assert_equal 1, @requests.size
    end
  end

  test "fetches individual records through the same authenticated connection" do
    client = client_for([ [ 200, {}, { data: { id: 27, title: "Project" } }.to_json ] ], resource: "projects/27")
    assert_equal({ "id" => 27, "title" => "Project" }, client.record("projects", 27))
    assert_equal "Bearer test-secret", @requests.sole.request_headers["Authorization"]
    @stubs.verify_stubbed_calls
  end
end
