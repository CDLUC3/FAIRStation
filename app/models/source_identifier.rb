class SourceIdentifier < ApplicationRecord
  belongs_to :record, polymorphic: true

  validates :source_system, :source_instance, :external_id, presence: true
  validates :external_id, uniqueness: { scope: [ :source_system, :source_instance ] }
end
