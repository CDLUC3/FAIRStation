class SourceAdapters
  ADAPTERS = {
    "rams" => -> { RamsAdapter.build }
  }.freeze

  def self.fetch(source)
    ADAPTERS.fetch(source).call
  rescue KeyError
    raise ArgumentError, "unknown research activity source #{source.inspect}"
  end
end
