class CandidateMatch < ApplicationRecord
  belongs_to :research_activity
  belongs_to :output

  validates :output_id, uniqueness: { scope: :research_activity_id }
  validates :score, numericality: true
  validates :review_status, inclusion: { in: %w[pending confirmed rejected] }
  validate :structured_evidence

  private

  def structured_evidence
    return if (evidence.is_a?(Hash) || evidence.is_a?(Array)) && evidence.present?

    errors.add(:evidence, "must be a nonempty object or array")
  end
end
