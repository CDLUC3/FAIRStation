class Station < ApplicationRecord
  has_many :source_identifiers, as: :record, dependent: :destroy, inverse_of: :record

  validates :name, presence: true
end
