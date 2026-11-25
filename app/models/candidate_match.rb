class CandidateMatch < ApplicationRecord
  belongs_to :station
  belongs_to :research_activity, optional: true
  belongs_to :output

  validates :output_id, uniqueness: { scope: :station_id }
  validates :score, numericality: true
  validates :review_status, inclusion: { in: %w[pending confirmed rejected] }
  validates :reviewed_score, numericality: true, unless: -> { review_status == "pending" }
  validate :research_activity_belongs_to_station
  validate :validate_evidence
  validate :validate_review_snapshot

  def record_review!(status:, score:, evidence:, note: nil)
    update!(review_status: status, review_note: note, reviewed_score: score, reviewed_evidence: evidence)
  end

  private

  def research_activity_belongs_to_station
    return if research_activity.nil? || research_activity.stations.exists?(id: station_id)

    errors.add(:research_activity, "must belong to the candidate's station")
  end

  def validate_evidence
    errors.add(:evidence, "must be a nonempty object or array") unless structured_evidence?(evidence)
  end

  def validate_review_snapshot
    if review_status == "pending"
      errors.add(:reviewed_evidence, "and score must be empty until reviewed") unless reviewed_evidence.nil? && reviewed_score.nil?
    else
      errors.add(:reviewed_evidence, "must be a nonempty object or array") unless structured_evidence?(reviewed_evidence)
    end
  end

  def structured_evidence?(value)
    (value.is_a?(Hash) || value.is_a?(Array)) && value.present?
  end
end
