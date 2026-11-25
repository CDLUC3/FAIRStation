class CreateOutputsAndCandidateMatches < ActiveRecord::Migration[8.1]
  def change # rubocop:disable Metrics/MethodLength
    create_table :outputs do |t|
      t.string :kind, null: false
      t.text :title
      t.string :doi
      t.text :url
      t.date :published_on
      t.datetime :retrieved_at
      t.timestamps

      t.index :doi, unique: true
      t.check_constraint "kind IN ('paper', 'dataset')", name: "outputs_kind"
    end

    create_table :candidate_matches do |t|
      t.references :station, null: false, foreign_key: true, index: false
      t.references :research_activity, foreign_key: { on_delete: :nullify }
      t.references :output, null: false, foreign_key: true
      t.float :score, null: false
      t.json :evidence
      t.string :review_status, default: "pending", null: false
      t.text :review_note
      t.float :reviewed_score
      t.json :reviewed_evidence
      t.timestamps

      t.index [ :station_id, :output_id ], unique: true
      t.check_constraint "review_status IN ('pending', 'confirmed', 'rejected')", name: "candidate_matches_review_status"
    end
  end
end
