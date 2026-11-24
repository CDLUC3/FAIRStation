class CandidateMatch < ApplicationRecord
  belongs_to :research_activity
  belongs_to :output

  validates :output_id, uniqueness: { scope: :research_activity_id }
  validates :score, numericality: true
  validates :review_status, inclusion: { in: %w[pending confirmed rejected] }
end
