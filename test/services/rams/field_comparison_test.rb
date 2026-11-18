require "test_helper"

class Rams::FieldComparisonTest < ActiveSupport::TestCase
  test "normalizes equivalent timestamp representations" do
    assert Rams::FieldComparison.call("2026-01-01T00:00:00Z", "2025-12-31T19:00:00-05:00")[:matches]
  end

  test "compares numeric representations without treating invalid text as zero" do
    assert Rams::FieldComparison.call(12, "12.00")[:matches]
    assert_not Rams::FieldComparison.call(0, "not a number")[:matches]
    assert_not Rams::FieldComparison.call(1, nil)[:matches]
  end

  test "keeps original values while comparing against an explicit normalized expectation" do
    result = Rams::FieldComparison.call("https://orcid.org/0000-0002-1825-0097", "0000-0002-1825-0097", expected: "0000-0002-1825-0097")
    assert result[:matches]
    assert_equal "https://orcid.org/0000-0002-1825-0097", result[:source]
  end
end
