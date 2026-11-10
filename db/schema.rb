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

ActiveRecord::Schema[8.1].define(version: 2026_11_10_185543) do
  create_table "activity_people", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "research_activity_id", null: false
    t.bigint "person_id", null: false
    t.string "role"
    t.boolean "active", default: true, null: false
    t.boolean "is_principal_investigator", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_activity_people_on_person_id"
    t.index ["research_activity_id", "person_id"], name: "index_activity_people_on_research_activity_id_and_person_id", unique: true
    t.index ["research_activity_id"], name: "index_activity_people_on_research_activity_id"
  end

  create_table "activity_stations", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "research_activity_id", null: false
    t.bigint "station_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["research_activity_id", "station_id"], name: "index_activity_stations_on_research_activity_id_and_station_id", unique: true
    t.index ["research_activity_id"], name: "index_activity_stations_on_research_activity_id"
    t.index ["station_id"], name: "index_activity_stations_on_station_id"
  end

  create_table "people", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "orcid"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["orcid"], name: "index_people_on_orcid", unique: true
  end

  create_table "research_activities", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "activity_type"
    t.string "status"
    t.date "start_date"
    t.date "end_date"
    t.string "discipline"
    t.string "discipline_other"
    t.text "keywords"
    t.text "taxonomic_keywords"
    t.string "thesis_title"
    t.string "course_title"
    t.string "course_number"
    t.datetime "submitted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "source_identifiers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.string "source_system", limit: 128, null: false
    t.string "external_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source_instance", limit: 128, null: false
    t.index ["record_type", "record_id"], name: "index_source_identifiers_on_record"
    t.index ["source_system", "source_instance", "record_type", "external_id"], name: "index_source_identifiers_on_source_identity", unique: true
  end

  create_table "stations", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "short_name"
    t.text "description"
    t.string "ror_id"
    t.string "doi"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "activity_people", "people"
  add_foreign_key "activity_people", "research_activities"
  add_foreign_key "activity_stations", "research_activities"
  add_foreign_key "activity_stations", "stations"
end
