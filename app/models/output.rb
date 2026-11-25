class Output < ApplicationRecord
  has_many :source_identifiers, as: :record, dependent: :destroy, inverse_of: :record
  has_many :candidate_matches, dependent: :destroy
  has_many :research_activities, -> { distinct }, through: :candidate_matches

  normalizes :doi, with: ->(value) { value.strip.downcase.sub(%r{\Ahttps?://(?:dx\.)?doi\.org/}, "").strip.presence }

  validates :kind, inclusion: { in: %w[paper dataset] }
  validates :doi, uniqueness: true, allow_nil: true
end
