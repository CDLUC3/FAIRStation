require "test_helper"

class PublicPagesTest < ActionDispatch::IntegrationTest
  test "landing page is publicly accessible as HTML" do
    get root_url

    assert_response :success
    assert_equal "text/html", response.media_type
  end

  test "deployment health check succeeds without a browser session" do
    get rails_health_check_url

    assert_response :success
  end
end
