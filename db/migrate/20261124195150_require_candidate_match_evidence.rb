class RequireCandidateMatchEvidence < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :candidate_matches,
      "evidence IS NOT NULL AND JSON_TYPE(evidence) IN ('OBJECT', 'ARRAY') AND JSON_LENGTH(evidence) > 0",
      name: "candidate_matches_evidence"

    add_check_constraint :candidate_matches, <<~SQL.squish, name: "candidate_matches_review_snapshot"
      (review_status = 'pending' AND reviewed_score IS NULL AND reviewed_evidence IS NULL)
      OR (review_status IN ('confirmed', 'rejected') AND reviewed_score IS NOT NULL AND reviewed_evidence IS NOT NULL
        AND JSON_TYPE(reviewed_evidence) IN ('OBJECT', 'ARRAY') AND JSON_LENGTH(reviewed_evidence) > 0)
    SQL
  end
end
