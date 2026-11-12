class ActivityStation < ApplicationRecord
  belongs_to :research_activity
  belongs_to :station
  has_many :source_identifiers, as: :record, dependent: :destroy, inverse_of: :record

  validates :station_id, uniqueness: { scope: :research_activity_id }
end
