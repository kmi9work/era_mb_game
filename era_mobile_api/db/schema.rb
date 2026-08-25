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

ActiveRecord::Schema[7.0].define(version: 2026_08_26_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "mb_caravans_mobile", force: :cascade do |t|
    t.bigint "guild_id", null: false
    t.bigint "country_id", null: false
    t.integer "year", null: false
    t.integer "status", default: 0, null: false
    t.json "sell_items", default: [], null: false
    t.json "buy_items", default: [], null: false
    t.integer "sale_income", default: 0, null: false
    t.integer "purchase_cost", default: 0, null: false
    t.integer "price_basis_year"
    t.float "roll_probability"
    t.boolean "precalculated_robbed", default: false, null: false
    t.boolean "contraband_used", default: false, null: false
    t.boolean "protected", default: false, null: false
    t.datetime "sent_at", null: false
    t.datetime "process_at", null: false
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id"], name: "index_mb_caravans_mobile_on_country_id"
    t.index ["guild_id", "country_id", "year"], name: "index_mb_caravans_mobile_on_guild_id_and_country_id_and_year"
    t.index ["guild_id"], name: "index_mb_caravans_mobile_on_guild_id"
    t.index ["process_at"], name: "index_mb_caravans_mobile_on_process_at"
  end

  create_table "mb_cards", force: :cascade do |t|
    t.string "owner_type", null: false
    t.bigint "owner_id", null: false
    t.string "card_kind", null: false
    t.string "political_action_type_action"
    t.integer "obtained_year", null: false
    t.integer "status", default: 0, null: false
    t.string "consumed_by_type"
    t.bigint "consumed_by_id"
    t.json "meta", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id", "card_kind", "status"], name: "idx_mb_cards_owner_kind_status"
    t.index ["owner_type", "owner_id", "status"], name: "index_mb_cards_on_owner_type_and_owner_id_and_status"
  end

  create_table "mb_notifications", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.string "kind", null: false
    t.string "title", null: false
    t.text "body"
    t.json "payload", default: {}, null: false
    t.boolean "read", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "read", "created_at"], name: "index_mb_notifications_on_player_id_and_read_and_created_at"
    t.index ["player_id"], name: "index_mb_notifications_on_player_id"
  end

  create_table "mb_operation_items", force: :cascade do |t|
    t.bigint "operation_id", null: false
    t.string "identificator", null: false
    t.string "name"
    t.integer "delta", null: false
    t.string "card_kind"
    t.boolean "is_card", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identificator"], name: "index_mb_operation_items_on_identificator"
    t.index ["operation_id"], name: "index_mb_operation_items_on_operation_id"
  end

  create_table "mb_operations", force: :cascade do |t|
    t.string "kind", null: false
    t.integer "year", null: false
    t.bigint "initiator_id"
    t.bigint "counterparty_id"
    t.string "counterparty_type"
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.string "ref_type"
    t.bigint "ref_id"
    t.string "idempotency_key"
    t.string "comment"
    t.json "meta", default: {}, null: false
    t.integer "status", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_mb_operations_on_idempotency_key", unique: true
    t.index ["initiator_id"], name: "index_mb_operations_on_initiator_id"
    t.index ["kind", "year"], name: "idx_mb_ops_kind_year"
    t.index ["subject_type", "subject_id", "created_at"], name: "idx_mb_ops_subject"
  end

  create_table "mb_push_tokens", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.string "platform", null: false
    t.string "token", null: false
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform", "token"], name: "index_mb_push_tokens_on_platform_and_token", unique: true
    t.index ["player_id"], name: "index_mb_push_tokens_on_player_id"
  end

  create_table "mb_scenario_configs", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "active", default: false, null: false
    t.json "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "mb_sessions", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.string "token_hash", null: false
    t.string "device_info"
    t.integer "status", default: 0, null: false
    t.datetime "last_seen_at"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "status"], name: "index_mb_sessions_on_player_id_and_status"
    t.index ["player_id"], name: "index_mb_sessions_on_player_id"
    t.index ["token_hash"], name: "index_mb_sessions_on_token_hash", unique: true
  end

  create_table "mb_trade_sessions", force: :cascade do |t|
    t.bigint "initiator_id", null: false
    t.bigint "partner_id", null: false
    t.integer "status", default: 0, null: false
    t.json "offers_a", default: {}, null: false
    t.json "offers_b", default: {}, null: false
    t.boolean "confirmed_a", default: false, null: false
    t.boolean "confirmed_b", default: false, null: false
    t.datetime "expires_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["initiator_id", "status"], name: "index_mb_trade_sessions_on_initiator_id_and_status"
    t.index ["initiator_id"], name: "index_mb_trade_sessions_on_initiator_id"
    t.index ["partner_id", "status"], name: "index_mb_trade_sessions_on_partner_id_and_status"
    t.index ["partner_id"], name: "index_mb_trade_sessions_on_partner_id"
  end

end
