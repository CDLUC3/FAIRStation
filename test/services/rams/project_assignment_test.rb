require "test_helper"
require_relative "../../support/rams_import"

class Rams::ProjectAssignmentTest < ActiveSupport::TestCase
  include RamsImport

  test "rejects conflicting ORCIDs in RAMS rows for the same user" do
    project = project_row(27)
    project["owner"] = project.fetch("owner").merge("orcid" => "0000-0001-2345-6789")

    assert_raises(Rams::Error) { sync }

    assert_empty Person.all
    assert_empty ResearchActivity.all
  end

  test "rejects an ORCID already held by another person and removes the archive" do
    existing = Person.create!(name: "Earlier name", orcid: "0000-0002-1825-0097")

    assert_raises(Imports::Error) { sync }

    assert_equal [ existing ], Person.all.to_a
    assert_equal "Earlier name", existing.reload.name
    assert_empty existing.source_identifiers
    assert_empty ResearchActivity.all
    assert_empty Dir.children(@evidence_directory)
  end

  test "rolls back the import when a known user's ORCID changes" do
    existing = Person.create!(name: "Earlier", orcid: "0000-0001-2345-6789")
    existing.source_identifiers.create!(**@adapter.source, external_id: "27")

    assert_raises(Imports::Error) { sync }

    assert_empty ResearchActivity.all
    assert_equal "Earlier", existing.reload.name
  end

  test "keeps two RAMS users with the same name separate" do
    project_row(34)["applicant"] = { "id" => 28, "full_name" => "Researcher", "orcid" => nil }

    sync

    assert_equal 2, Person.count
    assert_equal [ "Researcher" ], Person.distinct.pluck(:name)
    assert_not_equal source_identifier("Person", "27").record, source_identifier("Person", "28").record
  end

  test "a rerun adds owner and applicant links for a user without a team membership" do
    @rows.fetch("projects").each { |project| project["owner"] = nil }
    sync
    membership = team_membership

    user = { "id" => 28, "full_name" => "Researcher", "orcid" => nil }
    project_row(27).merge!("owner" => user, "applicant" => user)
    result = assert_difference("ActivityPerson.count", 2) { sync }

    person = source_identifier("Person", "28").record
    links = membership.research_activity.activity_people.where(person: person)
    assert_equal %w[applicant owner], links.order(:role).pluck(:role)
    assert_equal 3, result.fetch(:imported).fetch("ActivityPerson")
    assert_equal membership, team_membership
    assert_not_equal membership.person, person
  end

  test "a rerun with the same owner and applicant preserves their links" do
    project = project_row(27)
    project["applicant"] = project.fetch("owner")
    sync
    links = team_membership.research_activity.activity_people.order(:id)
    original_links = links.pluck(:id, :person_id, :role)

    assert_no_difference [ "ActivityPerson.count", "Person.count", "SourceIdentifier.count" ] do
      sync
    end

    assert_equal original_links, links.pluck(:id, :person_id, :role)
  end

  test "reassigning a project owner updates the same link and preserves the applicant" do
    project = project_row(27)
    project["applicant"] = project.fetch("owner")
    sync
    links = team_membership.research_activity.activity_people
    owner_link = links.find_by!(role: "owner")
    applicant_link = links.find_by!(role: "applicant")

    project["owner"] = { "id" => 28, "full_name" => "New owner", "orcid" => nil }
    assert_no_difference("ActivityPerson.count") { sync }

    new_owner = source_identifier("Person", "28").record
    assert_equal new_owner, owner_link.reload.person
    assert_equal team_membership.person, applicant_link.reload.person
  end

  test "the owner assignment splits from its shared membership and rejoins when the owner returns" do
    project = project_row(27)
    original_owner = project.fetch("owner")
    @rows.fetch("team_memberships").sole["user_role"] = "owner"

    assert_equal 8, sync.fetch(:imported).fetch("ActivityPerson")

    membership = team_membership
    original_person = membership.person
    assert_equal membership, source_identifier("ActivityPerson", "project/27/owner").record

    project["owner"] = { "id" => 28, "full_name" => "New owner", "orcid" => nil }
    assert_difference("ActivityPerson.count", 1) { sync }

    assert_equal membership, team_membership
    assert_equal original_person, membership.reload.person
    assert_equal "owner", membership.role
    assert_equal "University", membership.affiliation_name

    owner_link = source_identifier("ActivityPerson", "project/27/owner").record
    assert_equal "New owner", owner_link.person.name
    assert_equal "owner", owner_link.role
    assert_nil owner_link.affiliation_name

    project["owner"] = original_owner
    restored_run = assert_difference("ActivityPerson.count", -1) { sync }

    assignment = source_identifier("ActivityPerson", "project/27/owner")
    assert_equal restored_run.fetch(:import_run_id), assignment.import_run_id
    assert_equal membership, assignment.record
  end

  private

  def project_row(id)
    @rows.fetch("projects").find { |project| project.fetch("id") == id }
  end

  def source_identifier(record_type, external_id)
    SourceIdentifier.find_by!(**@connection.source, record_type: record_type, external_id: external_id)
  end
end
