require "test_helper"
require_relative "../../support/rams_import"

class Rams::ProjectMembershipTest < ActiveSupport::TestCase
  include RamsImport

  test "shared identity memberships can change roles together on a later run" do
    other = @rows.fetch("team_memberships").first.deep_dup
    other["id"] = 28
    @rows.fetch("team_memberships") << other
    result = sync
    assert_equal 9, ActivityPerson.count
    assert_equal 9, result.fetch(:imported).fetch("ActivityPerson")
    @rows.fetch("team_memberships").each { |row| row["user_role"] = "postdoc" }
    sync
    assert_equal "postdoc", team_membership.role
    assert_equal 2, team_membership.source_identifiers.count
  end

  test "conflicting incoming memberships roll back without changing the existing role" do
    sync
    other = @rows.fetch("team_memberships").first.deep_dup
    other["id"] = 28
    other["user_role"] = "postdoc"
    @rows.fetch("team_memberships") << other
    assert_raises(Imports::Error) { sync }
    assert_equal "graduate_student", team_membership.role
    assert_equal 1, team_membership.source_identifiers.count
  end

  test "a rerun stores the reported affiliation on each project membership" do
    first = @rows.fetch("team_memberships").sole
    institution = first["institution"]
    first["institution"] = nil
    sync
    existing = team_membership
    assert_nil existing.affiliation_source_id
    assert_nil existing.affiliation_name
    assert_nil existing.affiliation_ror_id

    first["institution"] = institution
    @rows.fetch("team_memberships") << first.merge(
      "id" => 28, "project" => { "id" => 34 }, "institution" => { "id" => 3, "name" => "Another University" }
    )
    result = sync

    assert_equal 1, Person.count
    assert_equal 10, existing.person.activity_people.count
    assert_equal "2", existing.reload.affiliation_source_id
    assert_equal "University", existing.affiliation_name
    assert_equal "https://ror.org/example", existing.affiliation_ror_id
    assert_equal result.fetch(:import_run_id), existing.source_identifiers.sole.import_run_id

    other = SourceIdentifier.find_by!(record_type: "ActivityPerson", external_id: "28").record
    assert_equal "3", other.affiliation_source_id
    assert_equal "Another University", other.affiliation_name
    assert_nil other.affiliation_ror_id
  end

  test "conflicting affiliations for one membership leave the previous import intact" do
    result = sync
    original = @rows.fetch("team_memberships").sole
    @rows.fetch("team_memberships") << original.merge(
      "id" => 28, "institution" => { "id" => 3, "name" => "Another University" }
    )

    error = assert_raises(Imports::Error) { sync }
    assert_match(/Conflicting incoming memberships/, error.message)
    membership = team_membership
    assert_equal "2", membership.affiliation_source_id
    assert_equal result.fetch(:import_run_id), membership.source_identifiers.sole.import_run_id
    assert_equal result.fetch(:import_run_id), ImportRun.sole.id
  end
end
