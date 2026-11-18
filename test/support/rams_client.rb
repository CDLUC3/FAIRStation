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
    @rows.fetch(resource).find { |row| row.fetch("id") == id }.deep_dup
  end
end
