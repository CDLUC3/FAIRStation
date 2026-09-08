class Participation < ApplicationRecord
  belongs_to :research_activity
  belongs_to :person
  belongs_to :organization, optional: true

  has_many :visit_participations, dependent: :destroy
  has_many :visits, through: :visit_participations

  validates :source, :source_id, :role, presence: true
  validates :source_id, uniqueness: { scope: :source }
end
