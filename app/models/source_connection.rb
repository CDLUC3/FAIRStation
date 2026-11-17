# Non-secret connection settings. Source identity belongs to an installation,
# so records shared by several stations retain the same identifier namespace.
SourceConnection = Data.define(:adapter, :base_url, :source, :credential_path) do
  def self.load(name)
    new(**Rails.application.config_for(:sources).fetch(name.to_sym))
  end

  def credential
    Rails.application.credentials.dig(*credential_path.map(&:to_sym))
  end
end
