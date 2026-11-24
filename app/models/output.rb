class Output < ApplicationRecord
  has_many :source_identifiers, as: :record, dependent: :destroy, inverse_of: :record
  has_many :candidate_matches, dependent: :destroy
  has_many :research_activities, through: :candidate_matches

  validates :kind, inclusion: { in: %w[paper dataset] }
end
