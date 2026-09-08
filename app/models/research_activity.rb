class ResearchActivity < ApplicationRecord
  has_many :participations, dependent: :destroy
  has_many :people, through: :participations
  has_many :visits, dependent: :destroy

  validates :source, :source_id, :title, presence: true
  validates :source_id, uniqueness: { scope: :source }
end
