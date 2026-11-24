require "test_helper"
require_relative "../../support/import_batches"

class Imports::PersonIdentityImportTest < ActiveSupport::TestCase
  include ImportBatches

  test "an asserted ORCID cannot link a new source identity to an existing person" do
    existing = Person.create!(name: "Earlier name", orcid: "0000-0002-1825-0097")
    input = batch.people.sole.with(attributes: { name: "Current source name", orcid: "https://orcid.org/0000-0002-1825-0097" })
    assert_raises(Imports::Error) { import(batch.with(people: [ input ])) }
    assert_equal 1, Person.count
    assert_equal "Earlier name", existing.reload.name
    assert_empty SourceIdentifier.all
    assert_empty Station.all
    assert_empty ResearchActivity.all
  end

  test "two source identities asserting the same ORCID fail atomically" do
    first = batch.people.sole.with(attributes: { name: "Same person", orcid: "0000-0002-1825-0097" })
    second = first.with(external_id: "person-b")
    assert_raises(Imports::Error) { import(batch.with(people: [ first, second ])) }
    assert_empty Person.all
    assert_empty SourceIdentifier.all
    assert_empty Station.all
  end

  test "a known source identity can refresh attributes without an ORCID merge" do
    input = batch.people.sole.with(attributes: { name: "Earlier name", orcid: "0000-0002-1825-0097" })
    import(batch.with(people: [ input ]))
    person = Person.sole
    refreshed = input.with(attributes: { name: "Current source name", orcid: "https://orcid.org/0000-0002-1825-0097" })
    import(batch.with(people: [ refreshed ]))
    assert_equal person, Person.sole
    assert_equal "Current source name", person.reload.name
    assert_equal 1, person.source_identifiers.count
  end

  test "contradictory ORCID and source identities fail atomically" do
    input = batch.people.sole.with(attributes: { name: "Person", orcid: "0000-0002-1825-0097" })
    import(batch.with(people: [ input ]))
    conflicting = input.with(attributes: { name: "Changed", orcid: "0000-0001-2345-6789" })
    assert_raises(Imports::Error) { import(batch.with(people: [ conflicting ])) }
    assert_equal "Person", Person.sole.name
    assert_equal "0000-0002-1825-0097", Person.sole.orcid
  end
end
