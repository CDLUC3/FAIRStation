require "test_helper"

class CandidateMatchTest < ActiveSupport::TestCase
  setup do
    @station = Station.create!(name: "Quail Ridge")
    @activity = ResearchActivity.create!(stations: [ @station ])
    @output = Output.create!(kind: "dataset", title: "Oak regeneration")
  end

  test "rescoring preserves the decision and the evidence shown to the reviewer" do
    shown_evidence = [ "Matching title" ]
    match = @station.candidate_matches.create!(research_activity: @activity, output: @output, score: 2, evidence: shown_evidence)
    assert_equal "pending", match.review_status

    match.update!(score: 3, evidence: { "terms" => [ "oak" ] })
    match.record_review!(status: "rejected", score: 2, evidence: shown_evidence, note: "Different site")
    CandidateMatch.find(match.id).update!(score: 4, evidence: { "terms" => [ "regeneration" ] })

    assert_equal [ @output ], @activity.outputs
    assert_equal [ @activity ], @output.research_activities
    assert_equal "rejected", match.reload.review_status
    assert_equal "Different site", match.review_note
    assert_equal 2, match.reviewed_score
    assert_equal shown_evidence, match.reviewed_evidence
    assert_equal 4, match.score
    assert_equal({ "terms" => [ "regeneration" ] }, match.evidence)
  end

  test "a station gets one lead for an output across projects or public discovery" do
    attributes = { station_id: @station.id, output_id: @output.id, score: 1, evidence: [ "Matching title" ] }
    match = CandidateMatch.create!(attributes)
    assert_nil match.research_activity

    duplicate = CandidateMatch.new(**attributes, research_activity: @activity)
    assert_not duplicate.valid?
    assert duplicate.errors[:output_id].any?
    assert_raises ActiveRecord::RecordNotUnique do
      CandidateMatch.insert_all!([ attributes.merge(research_activity_id: @activity.id) ])
    end
  end

  test "two stations on the same project review the same output independently" do
    other_station = Station.create!(name: "Lassen")
    @activity.stations << other_station
    attributes = { research_activity: @activity, output: @output, score: 1, evidence: [ "Matching title" ] }
    match = @station.candidate_matches.create!(attributes)
    other_match = other_station.candidate_matches.create!(attributes)

    match.record_review!(status: "confirmed", score: match.score, evidence: match.evidence)
    assert_equal "pending", other_match.reload.review_status
    assert_equal [ @output ], @activity.outputs
  end

  test "a suggested project must belong to the candidate's station" do
    station = Station.create!(name: "Lassen")
    match = station.candidate_matches.build(research_activity: @activity, output: @output, score: 1, evidence: [ "Matching title" ])

    assert_not match.valid?
    assert match.errors[:research_activity].any?
  end

  test "deleting the suggested project keeps the lead and its review" do
    match = @station.candidate_matches.create!(research_activity: @activity, output: @output, score: 1, evidence: [ "Matching title" ])
    match.record_review!(status: "confirmed", score: match.score, evidence: match.evidence)

    @activity.destroy!

    assert_nil match.reload.research_activity_id
    assert_equal "confirmed", match.review_status
    assert_equal [ "Matching title" ], match.reviewed_evidence
  end

  test "both model saves and bulk writes require nonempty structured evidence" do
    attributes = { station_id: @station.id, output_id: @output.id, score: 1 }

    [ nil, {}, [], "oak", 1, false ].each do |evidence|
      match = CandidateMatch.new(**attributes, evidence: evidence)
      assert_not match.save, "Model accepted #{evidence.inspect}"
      assert match.errors[:evidence].any?
      assert_raises ActiveRecord::StatementInvalid do
        CandidateMatch.insert_all!([ attributes.merge(evidence: evidence) ])
      end
    end
  end

  test "both model saves and bulk writes require a snapshot for a decision" do
    attributes = { station_id: @station.id, output_id: @output.id, score: 1, evidence: [ "Matching title" ], review_status: "confirmed" }
    match = CandidateMatch.new(attributes)

    assert_not match.valid?
    assert match.errors[:reviewed_evidence].any?
    assert_raises ActiveRecord::StatementInvalid do
      CandidateMatch.insert_all!([ attributes ])
    end
  end

  test "candidate requires a numeric score and a recognized review status" do
    match = @station.candidate_matches.build(output: @output, score: "unknown", review_status: "unknown")
    assert_not match.valid?
    assert match.errors[:score].any?
    assert match.errors[:review_status].any?
  end
end
