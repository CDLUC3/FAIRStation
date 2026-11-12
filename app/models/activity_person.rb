class ActivityPerson < ApplicationRecord
  belongs_to :research_activity
  belongs_to :person
  has_many :source_identifiers, as: :record, dependent: :destroy, inverse_of: :record

  validates :person_id, uniqueness: { scope: :research_activity_id }
  validates :active, :is_principal_investigator, inclusion: { in: [ true, false ] }
end
