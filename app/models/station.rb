class Station < ApplicationRecord
  has_many :source_identifiers, as: :record, dependent: :destroy, inverse_of: :record

  has_many :activity_stations, dependent: :restrict_with_error
  has_many :research_activities, through: :activity_stations

  validates :name, presence: true
end
