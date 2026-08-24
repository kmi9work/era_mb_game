# frozen_string_literal: true

# Песочница общих таблиц eraofchange для разработки и тестов.
# ТЗ 6.2: схему общих таблиц меняем только в репозитории eraofchange — здесь она
# воспроизводится в минимальном объёме, необходимом моделям Shared::* и тестам.
#
#   bundle exec rails era_sandbox:install            # dev-база
#   RAILS_ENV=test bundle exec rake era_sandbox:install
namespace :era_sandbox do
  desc "Создать песочницу общих таблиц eraofchange в текущей БД"
  task install: :environment do
    conn = ActiveRecord::Base.connection

    create = ->(name, id_primary: true) { conn.create_table(name, id: id_primary, if_not_exists: true) { |t| yield_block(t) } }
    _ = create # (не используется напрямую; ниже явные вызовы)

    unless conn.table_exists?("jobs")
      conn.create_table("jobs") do |t|
        t.string :name
        t.timestamps
      end
    end

    unless conn.table_exists?("jobs_players")
      conn.create_table("jobs_players", id: false) do |t|
        t.bigint :job_id
        t.bigint :player_id
      end
    end

    unless conn.table_exists?("guilds")
      conn.create_table("guilds") do |t|
        t.string :name
        t.string :icon
        t.json :params
        t.timestamps
      end
    end

    unless conn.table_exists?("players")
      conn.create_table("players") do |t|
        t.string :name
        t.string :identificator, null: false
        t.integer :human_id
        t.integer :player_type_id
        t.integer :family_id
        t.integer :guild_id
        t.json :resources
        t.json :params, default: {}
        t.timestamps
        t.index :identificator, unique: true
      end
    end

    unless conn.table_exists?("resource_items")
      conn.create_table("resource_items") do |t|
        t.integer :economic_subject_id
        t.string  :economic_subject_type
        t.string  :identificator, null: false
        t.integer :count, default: 0, null: false
        t.timestamps
        t.index %i[economic_subject_type economic_subject_id identificator],
                name: "index_resource_items_on_subject_and_identificator", unique: true
        t.index %i[economic_subject_type economic_subject_id], name: "index_resource_items_on_economic_subject"
      end
    end

    unless conn.table_exists?("plant_categories")
      conn.create_table("plant_categories") do |t|
        t.string :name
        t.boolean :is_extractive
        t.timestamps
      end
    end

    unless conn.table_exists?("fossil_types")
      conn.create_table("fossil_types") do |t|
        t.string :name
        t.timestamps
      end
    end

    unless conn.table_exists?("fossil_types_plant_places")
      conn.create_table("fossil_types_plant_places", id: false) do |t|
        t.bigint :fossil_type_id
        t.bigint :plant_place_id
      end
    end

    unless conn.table_exists?("plant_types")
      conn.create_table("plant_types") do |t|
        t.string :name
        t.integer :plant_category_id
        t.integer :fossil_type_id
        t.string :icon
        t.timestamps
      end
    end

    unless conn.table_exists?("plant_levels")
      conn.create_table("plant_levels") do |t|
        t.integer :level
        t.integer :deposit
        t.json :formulas
        t.json :price
        t.integer :plant_type_id
        t.timestamps
      end
    end

    unless conn.table_exists?("countries")
      conn.create_table("countries") do |t|
        t.string :name
        t.string :short_name
        t.string :flag_image_name
        t.json :params
        t.timestamps
      end
    end

    unless conn.table_exists?("regions")
      conn.create_table("regions") do |t|
        t.string :name
        t.integer :country_id
        t.integer :player_id
        t.json :params
        t.timestamps
      end
    end

    unless conn.table_exists?("plant_places")
      conn.create_table("plant_places") do |t|
        t.string :name
        t.integer :plant_category_id
        t.integer :region_id
        t.timestamps
      end
    end

    unless conn.table_exists?("relation_items")
      conn.create_table("relation_items") do |t|
        t.integer :value
        t.integer :country_id
        t.integer :entity_id
        t.string :entity_type
        t.string :comment
        t.integer :year
        t.timestamps
      end
    end

    unless conn.table_exists?("resources")
      conn.create_table("resources") do |t|
        t.string :name
        t.string :identificator
        t.integer :country_id
        t.json :params
        t.string :icon
        t.timestamps
        t.index [:identificator, :country_id], unique: true
      end
    end

    unless conn.table_exists?("plants")
      conn.create_table("plants") do |t|
        t.string :comments
        t.integer :plant_level_id
        t.integer :plant_place_id
        t.integer :economic_subject_id
        t.string  :economic_subject_type
        t.integer :credit_id
        t.json :params
        t.timestamps
      end
    end

    unless conn.table_exists?("game_parameters")
      conn.create_table("game_parameters") do |t|
        t.string :name
        t.string :identificator
        t.string :value
        t.json :params
        t.timestamps
      end
    end

    unless conn.table_exists?("technologies")
      conn.create_table("technologies") do |t|
        t.string :name
        t.string :description
        t.json :params
        t.timestamps
      end
    end

    unless conn.table_exists?("technology_items")
      conn.create_table("technology_items") do |t|
        t.integer :value
        t.integer :year
        t.string :comment
        t.integer :technology_id
        t.integer :entity_id
        t.string :entity_type
        t.timestamps
      end
    end

    unless conn.table_exists?("political_action_types")
      conn.create_table("political_action_types") do |t|
        t.string :icon
        t.string :name
        t.string :action
        t.integer :job_id
        t.json :params
        t.text :description
        t.string :cost
        t.string :probability
        t.text :success
        t.text :failure
        t.timestamps
      end
    end

    unless conn.table_exists?("caravans")
      conn.create_table("caravans") do |t|
        t.integer :country_id
        t.integer :guild_id
        t.integer :year
        t.json :resources_export
        t.json :resources_import
        t.integer :gold_export
        t.integer :gold_import
        t.boolean :via_vyatka
        t.boolean :is_robbed
        t.timestamps
      end
    end

    puts "era_sandbox: shared tables ready in #{conn.current_database}"
  end
end
