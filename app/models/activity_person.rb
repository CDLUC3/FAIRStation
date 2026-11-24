class ActivityPerson < ApplicationRecord
  belongs_to :research_activity
  belongs_to :person
  has_many :source_identifiers, as: :record, dependent: :destroy, inverse_of: :record

  validates :person_id, uniqueness: { scope: [ :research_activity_id, :role ] }
  validates :active, :is_principal_investigator, inclusion: { in: [ true, false ] }

  def reset_membership_details!
    update!(active: true, is_principal_investigator: false,
      affiliation_source_id: nil, affiliation_name: nil, affiliation_ror_id: nil)
  end
end
