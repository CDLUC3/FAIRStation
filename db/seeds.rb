# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Quail Ridge Reserve is the MVP's first station. Verified on 2026-11-05:
# RAMS API: https://rams.ucnature.org/api/v1/reserves (reserve 27)
# DOI: https://ucnature.org/research/research-resources/reserve-doi/
# Coordinates: https://ucnature.org/find-a-reserve/reserve-coordinates/
# Use UC Nature's negative longitude; RAMS reports a positive longitude.
# No station-specific ROR record was found, so ror_id remains blank.
Station.transaction do
  station = Station.find_or_initialize_by(name: "Quail Ridge Reserve")
  station.update!(doi: "10.21973/N30T0K", latitude: "38.48277778", longitude: "-122.14944444", ror_id: nil)
  station.source_identifiers.find_or_create_by!(source_system: "rams", source_instance: "ucnature", external_id: "27")
end
