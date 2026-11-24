class RequireCandidateMatchEvidence < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :candidate_matches,
      "evidence IS NOT NULL AND JSON_TYPE(evidence) IN ('OBJECT', 'ARRAY') AND JSON_LENGTH(evidence) > 0",
      name: "candidate_matches_evidence"
  end
end
