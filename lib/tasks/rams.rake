namespace :rams do
  desc "Full Quail Ridge production pull into development; write validation evidence under tmp"
  task sync_quail_ridge: :environment do
    abort "RAMS test sync runs only in FAIR Station development" unless Rails.env.development?

    # An env token is an explicit allowance for this local test run only.
    token = ENV["RAMS_API_TOKEN"].presence || Rails.application.credentials.dig(:rams, :api_token)
    client = Rams::Client.new(token: token)
    report = Rams::QuailRidgeSync.new(client: client).call
    path = Rails.root.join("tmp/rams-sync", "#{Time.current.utc.strftime('%Y%m%dT%H%M%S%6NZ')}.json")
    FileUtils.mkdir_p(path.dirname, mode: 0o700)
    File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(JSON.pretty_generate(report)) }
    report.fetch(:dropped_fields).each do |resource, fields|
      puts "Not imported from #{resource}: #{fields.keys.join(', ')}"
    end
    puts "Unmodeled project relationships: #{report.fetch(:unmodeled_relationships)}"
    puts "Station source differences preserved: #{report.fetch(:station_differences_preserved).keys.join(', ')}"
    puts "Spot-checked #{report.fetch(:spot_checks).size} projects; sample shortfall: #{report.fetch(:sample_shortfall)}"
    puts "Validation evidence: #{path}"
  end
end
