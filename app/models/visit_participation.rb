class VisitParticipation < ApplicationRecord
  belongs_to :visit
  belongs_to :participation

  validates :source, :source_id, presence: true
  validates :source_id, uniqueness: { scope: :source }
  validates :participation_id, uniqueness: { scope: :visit_id }
  validate :participation_belongs_to_visit_activity

  private

  def participation_belongs_to_visit_activity
    return if visit.blank? || participation.blank?
    return if visit.research_activity == participation.research_activity

    errors.add(:participation, "must belong to the visit's research activity")
  end
end
