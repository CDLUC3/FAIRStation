class ResearchActivity < ApplicationRecord
  has_many :activity_stations, dependent: :destroy, inverse_of: :research_activity
  has_many :stations, through: :activity_stations
  has_many :activity_people, dependent: :destroy, inverse_of: :research_activity
  has_many :people, through: :activity_people
  has_many :source_identifiers, as: :record, dependent: :destroy, inverse_of: :record

  validates :stations, presence: true
end
