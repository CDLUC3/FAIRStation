class RamsTestClient
  attr_reader :requests, :rows, :transaction_depths

  def initialize(rows)
    @rows, @requests, @transaction_depths = rows, [], []
  end

  def collection(resource, **filters)
    @transaction_depths << ApplicationRecord.connection.open_transactions
    @requests << [ resource, filters ]
    data = @rows.fetch(resource)
    { "data" => data, "total_count" => data.size }
  end

  def record(resource, id)
    @transaction_depths << ApplicationRecord.connection.open_transactions
    @requests << [ "#{resource}/#{id}", {} ]
    row = @rows.fetch(resource).find { |candidate| candidate.fetch("id") == id }
    raise Rams::Error, "RAMS HTTP 404 for #{resource}/#{id}" unless row
    row.deep_dup
  end
end
