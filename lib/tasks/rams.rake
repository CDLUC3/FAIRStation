namespace :rams do
  desc "Import a RAMS connection and selected reserve into development, with a local source archive"
  task :sync, [ :connection, :reserve_id ] => :environment do |_, args|
    abort "RAMS test sync runs only in FAIR Station development" unless Rails.env.development?
    abort "Usage: bin/rails 'rams:sync[connection,reserve_id]'" if args[:connection].blank? || args[:reserve_id].blank?

    connection = SourceConnection.load(args[:connection])
    adapter = Rams::Adapter.new(connection: connection, reserve_id: args[:reserve_id])
    client = Rams::Client.new(token: connection.credential, base_url: connection.base_url)
    result = Imports::Sync.new(adapter: adapter, client: client).call
    result.fetch(:counts).each do |resource, counts|
      puts "#{resource}: pulled #{counts.fetch(:pulled)} / source #{counts.fetch(:total)}"
    end
    puts "Imported records: #{result.fetch(:imported)}"
    puts "Local source archive: #{result.fetch(:evidence)}"
  end
end
