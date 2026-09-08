namespace :fair_station do
  desc "Pull and import one research activity from a configured source"
  task :import, %i[source source_id] => :environment do |_task, args|
    unless args[:source].present? && args[:source_id].present?
      abort "Usage: bin/rails 'fair_station:import[source,source_id]'"
    end

    activity = ImportResearchActivity.new.call(
      adapter: SourceAdapters.fetch(args[:source]),
      source_id: args[:source_id]
    )

    puts "Imported ResearchActivity #{activity.id} from #{activity.source}:#{activity.source_id}"
  end
end
