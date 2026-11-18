# A committed sync receipt. Failed attempts never persist a receipt.
class ImportRun < ApplicationRecord
  has_many :source_identifiers, dependent: :restrict_with_exception

  validates :source_system, :source_instance, :station_external_id, :retrieved_at, :successful_at,
    :snapshot_path, :metadata_path, :snapshot_sha256, :metadata_sha256, presence: true
  validates :source_system, :source_instance, length: { maximum: 128 }
  validates :snapshot_sha256, :metadata_sha256, format: { with: /\A[0-9a-f]{64}\z/ }

  def self.last_successful_sync(source:, station_external_id:)
    where(**source, station_external_id: station_external_id.to_s).maximum(:successful_at)
  end
end
