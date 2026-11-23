require "test_helper"
require_relative "../../support/rams_import"

class Rams::ProjectAssignmentTest < ActiveSupport::TestCase
  include RamsImport

  test "conflicting ORCID assertions for the same user are not silently deduplicated" do
    @rows.fetch("projects").first["owner"] = @rows.fetch("projects").first.fetch("owner").merge("orcid" => "0000-0001-2345-6789")
    assert_raises(Rams::Error) { sync }
    assert_empty Person.all
    assert_empty ResearchActivity.all
  end

  test "an asserted ORCID collision stops the import and removes its archive" do
    existing = Person.create!(name: "Earlier name", orcid: "0000-0002-1825-0097")
    assert_raises(Imports::Error) { sync }
    assert_equal [ existing ], Person.all.to_a
    assert_equal "Earlier name", existing.reload.name
    assert_empty existing.source_identifiers
    assert_empty ResearchActivity.all
    assert_empty Dir.children(@evidence_directory)
  end

  test "names alone never merge source identities" do
    @rows["projects"].last["applicant"] = { "id" => 28, "full_name" => "Researcher", "orcid" => nil }
    sync
    assert_equal 2, Person.count
    assert_equal [ "Researcher" ], Person.distinct.pluck(:name)
    people = SourceIdentifier.where(record_type: "Person", external_id: %w[27 28]).pluck(:record_id)
    assert_equal 2, people.uniq.size
  end

  test "rerunning sync backfills both project roles for a user without a team membership" do
    @rows["projects"].each { |project| project["owner"] = nil }
    sync
    membership = team_membership

    user = { "id" => 28, "full_name" => "Researcher", "orcid" => nil }
    @rows["projects"].first.merge!("owner" => user, "applicant" => user)
    result = nil
    assert_difference "ActivityPerson.count", 2 do
      result = sync
    end

    person = SourceIdentifier.find_by!(**@connection.source, record_type: "Person", external_id: "28").record
    assert_equal %w[applicant owner], membership.research_activity.activity_people.where(person: person).order(:role).pluck(:role)
    assert_equal 3, result.fetch(:imported).fetch("ActivityPerson")
    assert_equal membership.id, team_membership.id
    assert_not_equal membership.person, person
  end

  test "unchanged project roles keep their links across reruns" do
    project = @rows["projects"].first
    project["applicant"] = project.fetch("owner")
    sync
    links = team_membership.research_activity.activity_people
    first_run = links.order(:id).pluck(:id, :person_id, :role)

    assert_no_difference [ "ActivityPerson.count", "Person.count", "SourceIdentifier.count" ] do
      sync
    end
    assert_equal first_run, links.order(:id).pluck(:id, :person_id, :role)
  end

  test "reassigning a project owner updates the same link and preserves the applicant" do
    project = @rows["projects"].first
    project["applicant"] = project.fetch("owner")
    sync
    links = team_membership.research_activity.activity_people
    owner = links.find_by!(role: "owner")
    applicant = links.find_by!(role: "applicant")

    project["owner"] = { "id" => 28, "full_name" => "New owner", "orcid" => nil }
    assert_no_difference("ActivityPerson.count") { sync }

    person = SourceIdentifier.find_by!(**@connection.source, record_type: "Person", external_id: "28").record
    assert_equal person, owner.reload.person
    assert_equal team_membership.person, applicant.reload.person
  end

  test "conflicting ORCIDs roll back the entire import" do
    person = Person.create!(name: "Earlier", orcid: "0000-0001-2345-6789")
    person.source_identifiers.create!(**@adapter.source, external_id: "27")
    assert_raises(Imports::Error) { sync }
    assert_empty ResearchActivity.all
    assert_equal "Earlier", person.reload.name
  end
end
