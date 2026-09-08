class Visit < ApplicationRecord
  belongs_to :research_activity
  belongs_to :station

  has_many :visit_participations, dependent: :destroy
  has_many :participations, through: :visit_participations

  validates :source, :source_id, :starts_at, presence: true
  validates :source_id, uniqueness: { scope: :source }
  validate :ends_at_is_not_before_starts_at

  private

  def ends_at_is_not_before_starts_at
    return if starts_at.blank? || ends_at.blank? || ends_at >= starts_at

    errors.add(:ends_at, "must be on or after starts_at")
  end
end
