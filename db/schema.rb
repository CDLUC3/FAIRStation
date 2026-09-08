# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_04_152135) do
  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "source", null: false
    t.string "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["source", "source_id"], name: "index_organizations_on_source_and_source_id", unique: true
  end

  create_table "participations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "organization_id"
    t.integer "person_id", null: false
    t.integer "research_activity_id", null: false
    t.string "role", null: false
    t.string "source", null: false
    t.string "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_participations_on_organization_id"
    t.index ["person_id"], name: "index_participations_on_person_id"
    t.index ["research_activity_id"], name: "index_participations_on_research_activity_id"
    t.index ["source", "source_id"], name: "index_participations_on_source_and_source_id", unique: true
  end

  create_table "people", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "source", null: false
    t.string "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["source", "source_id"], name: "index_people_on_source_and_source_id", unique: true
  end

  create_table "research_activities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "first_visit_evidence_source_id"
    t.datetime "first_visit_started_at"
    t.string "source", null: false
    t.string "source_id", null: false
    t.datetime "source_record_created_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["source", "source_id"], name: "index_research_activities_on_source_and_source_id", unique: true
  end

  create_table "stations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "source", null: false
    t.string "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["source", "source_id"], name: "index_stations_on_source_and_source_id", unique: true
  end

  create_table "visit_participations", force: :cascade do |t|
    t.datetime "arrives_at"
    t.datetime "created_at", null: false
    t.datetime "departs_at"
    t.integer "participation_id", null: false
    t.string "source", null: false
    t.string "source_id", null: false
    t.datetime "updated_at", null: false
    t.integer "visit_id", null: false
    t.index ["participation_id"], name: "index_visit_participations_on_participation_id"
    t.index ["source", "source_id"], name: "index_visit_participations_on_source_and_source_id", unique: true
    t.index ["visit_id", "participation_id"], name: "index_visit_participations_on_visit_id_and_participation_id", unique: true
    t.index ["visit_id"], name: "index_visit_participations_on_visit_id"
  end

  create_table "visits", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ends_at"
    t.integer "research_activity_id", null: false
    t.string "source", null: false
    t.string "source_id", null: false
    t.string "source_status"
    t.datetime "starts_at", null: false
    t.integer "station_id", null: false
    t.datetime "updated_at", null: false
    t.index ["research_activity_id"], name: "index_visits_on_research_activity_id"
    t.index ["source", "source_id"], name: "index_visits_on_source_and_source_id", unique: true
    t.index ["station_id"], name: "index_visits_on_station_id"
  end

  add_foreign_key "participations", "organizations"
  add_foreign_key "participations", "people"
  add_foreign_key "participations", "research_activities"
  add_foreign_key "visit_participations", "participations"
  add_foreign_key "visit_participations", "visits"
  add_foreign_key "visits", "research_activities"
  add_foreign_key "visits", "stations"
end
