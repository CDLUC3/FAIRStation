class Person < ApplicationRecord
  has_many :activity_people, dependent: :destroy, inverse_of: :person
  has_many :research_activities, through: :activity_people
  has_many :source_identifiers, as: :record, dependent: :destroy, inverse_of: :record

  normalizes :orcid, with: ->(value) { value.strip.delete_prefix("https://orcid.org/").upcase.presence }

  validates :name, presence: true
  validates :orcid, uniqueness: true, allow_nil: true, format: { with: /\A\d{4}-\d{4}-\d{4}-\d{3}[\dX]\z/ }
end
