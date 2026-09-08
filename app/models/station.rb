class Station < ApplicationRecord
  has_many :visits, dependent: :restrict_with_exception

  validates :source, :source_id, :name, presence: true
  validates :source_id, uniqueness: { scope: :source }
end
