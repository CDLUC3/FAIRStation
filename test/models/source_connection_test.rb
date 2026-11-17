require "test_helper"

class SourceConnectionTest < ActiveSupport::TestCase
  test "loads an installation independently of its reserves" do
    connection = SourceConnection.load(:ucnature)
    assert_equal "rams", connection.adapter
    assert_equal "https://rams.ucnature.org/api/v1/", connection.base_url
    assert_equal({ source_system: "rams", source_instance: "ucnature" }, connection.source)
    assert_equal %w[rams api_token], connection.credential_path
  end

  test "unknown connections fail rather than falling back to another installation" do
    assert_raises(KeyError) { SourceConnection.load(:unknown) }
  end
end
