require "test_helper"

class ActivityPersonTest < ActiveSupport::TestCase
  setup do
    @activity = ResearchActivity.create!(stations: [ Station.create!(name: "Quail Ridge") ])
    @person = Person.create!(name: "Researcher", orcid: "0000-0002-1825-0097")
  end

  test "requires both records" do
    membership = ActivityPerson.new
    assert_not membership.valid?
    assert_includes membership.errors[:research_activity], "must exist"
    assert_includes membership.errors[:person], "must exist"
  end

  test "holds role and membership status independently per activity" do
    membership = @activity.activity_people.create!(person: @person, role: "graduate_student", is_principal_investigator: true)
    other = ResearchActivity.create!(stations: @activity.stations)
    other.activity_people.create!(person: @person, role: nil, active: false)

    assert_equal "graduate_student", membership.reload.role
    assert membership.is_principal_investigator?
    assert_includes @activity.people, @person
    assert_equal 2, @person.research_activities.count
  end

  test "prevents duplicate memberships in model and database" do
    attributes = { research_activity: @activity, person: @person }
    ActivityPerson.create!(attributes)
    assert_not ActivityPerson.new(attributes).valid?
    assert_raises(ActiveRecord::RecordNotUnique) do
      ActivityPerson.insert_all!([ { research_activity_id: @activity.id, person_id: @person.id } ])
    end
  end

  test "destroying a person removes memberships but preserves activities" do
    @activity.activity_people.create!(person: @person)
    @person.destroy!
    assert_empty @activity.reload.activity_people
    assert ResearchActivity.exists?(@activity.id)
  end
end
