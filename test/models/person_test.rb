require "test_helper"

class PersonTest < ActiveSupport::TestCase
  test "requires a name and an ORCID" do
    person = Person.new
    assert_not person.valid?
    assert_includes person.errors[:name], "can't be blank"
    assert_includes person.errors[:orcid], "can't be blank"
  end

  test "normalizes ORCID URLs and rejects duplicate identities" do
    person = Person.create!(name: "Researcher", orcid: " https://orcid.org/0000-0002-1825-0097 ")
    assert_equal "0000-0002-1825-0097", person.reload.orcid
    duplicate = Person.new(name: "Another name", orcid: person.orcid)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:orcid], "has already been taken"
    assert_raises(ActiveRecord::RecordNotUnique) do
      Person.insert_all!([ { name: "Duplicate", orcid: person.orcid } ])
    end
  end

  test "accepts X check digit and rejects malformed identifiers" do
    assert Person.new(name: "Researcher", orcid: "0000-0002-1694-233x").valid?
    assert_not Person.new(name: "Researcher", orcid: "RAMS-42").valid?
  end

  test "links source identities and removes them with the person" do
    person = Person.create!(name: "Researcher", orcid: "0000-0002-1825-0097")
    identifier = person.source_identifiers.create!(source_system: "rams", source_instance: "ucnature", external_id: "user-42")
    assert_equal person, identifier.record
    person.destroy!
    assert_not SourceIdentifier.exists?(identifier.id)
  end
end
