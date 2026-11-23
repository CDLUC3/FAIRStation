require_relative "../../support/rams_import_test_case"

class Rams::ImportPersonIdentityTest < RamsImportTestCase
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
    @rows["team_memberships"] << @rows["team_memberships"].first.merge("id" => 28, "project" => { "id" => 34 }, "user" => @rows["projects"].last["applicant"])
    sync
    assert_equal 2, Person.count
    assert_equal [ "Researcher" ], Person.distinct.pluck(:name)
    people = SourceIdentifier.where(record_type: "Person", external_id: %w[27 28]).pluck(:record_id)
    assert_equal 2, people.uniq.size
  end

  test "unlinked owners and applicants remain in the archive without creating people" do
    @rows["projects"].last["applicant"] = { "id" => 28, "full_name" => "Unlinked applicant", "orcid" => nil }
    result = sync
    assert_equal 1, Person.count
    assert_not SourceIdentifier.exists?(record_type: "Person", external_id: "28")
    saved = JSON.parse(File.read(result.fetch(:evidence).fetch(:snapshot)))
    assert_equal 28, saved.fetch("projects").fetch("data").last.fetch("applicant").fetch("id")
  end

  test "conflicting ORCIDs roll back the entire import" do
    person = Person.create!(name: "Earlier", orcid: "0000-0001-2345-6789")
    person.source_identifiers.create!(**@adapter.source, external_id: "27")
    assert_raises(Imports::Error) { sync }
    assert_empty ResearchActivity.all
    assert_equal "Earlier", person.reload.name
  end
end
