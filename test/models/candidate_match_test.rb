require "test_helper"

class CandidateMatchTest < ActiveSupport::TestCase
  setup do
    @activity = ResearchActivity.create!(stations: [ Station.create!(name: "Quail Ridge") ])
    @output = Output.create!(kind: "dataset", title: "Oak regeneration")
  end

  test "rescoring preserves review decisions and structured evidence" do
    match = @activity.candidate_matches.create!(output: @output, score: 2)
    assert_equal "pending", match.review_status
    match.update!(review_status: "rejected", review_note: "Different site")

    candidate = CandidateMatch.find_or_initialize_by(research_activity: @activity, output: @output)
    candidate.update!(score: 3, evidence: { "terms" => [ "oak" ] })

    assert_equal [ @output ], @activity.outputs
    assert_equal [ @activity ], @output.research_activities
    assert_equal "rejected", match.reload.review_status
    assert_equal "Different site", match.review_note
    assert_equal({ "terms" => [ "oak" ] }, match.evidence)
  end

  test "database prevents duplicate candidates for an activity" do
    match = @activity.candidate_matches.create!(output: @output, score: 1)
    assert_not match.dup.valid?
    assert_raises ActiveRecord::RecordNotUnique do
      CandidateMatch.insert_all!([ { output_id: @output.id, research_activity_id: @activity.id, score: 2 } ])
    end
  end

  test "candidate requires a numeric score and a recognized review status" do
    match = @activity.candidate_matches.build(output: @output, score: "unknown", review_status: "unknown")
    assert_not match.valid?
    assert match.errors[:score].any?
    assert match.errors[:review_status].any?
  end
end
