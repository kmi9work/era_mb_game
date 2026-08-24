# frozen_string_literal: true

FactoryBot.define do
  factory :guild, class: "Shared::Guild" do
    sequence(:name) { |n| "Гильдия #{n}" }
    params { {} }
  end

  factory :player, class: "Shared::Player" do
    sequence(:name) { |n| "Купец #{n}" }
    sequence(:identificator) { |n| "P#{format('%05d', n)}" }
    guild
  end

  factory :resource_item, class: "Shared::ResourceItem" do
    economic_subject_type { "Guild" }
    association :economic_subject, factory: :guild
    identificator { "gold" }
    count { 1000 }
  end

  factory :country, class: "Shared::Country" do
    sequence(:name) { |n| "Страна #{n}" }
    params { {} }
  end

  factory :relation_item, class: "Shared::RelationItem" do
    value { 0 }
    country
    year { 1 }
    comment { "test" }
  end

  factory :plant_category_extractive, class: "Shared::PlantCategory" do
    name { "Добывающее" }
    is_extractive { true }
  end

  factory :plant_category_processing, class: "Shared::PlantCategory" do
    name { "Перерабатывающее" }
    is_extractive { false }
  end

  factory :fossil_type, class: "Shared::FossilType" do
    sequence(:name) { |n| "Залежь #{n}" }
  end

  factory :plant_type, class: "Shared::PlantType" do
    sequence(:name) { |n| "Тип #{n}" }
    plant_category factory: :plant_category_processing
  end

  factory :plant_level, class: "Shared::PlantLevel" do
    level { 1 }
    deposit { 500 }
    price { { "gold" => 300 } }
    formulas do
      [{ "from" => [], "to" => [{ "identificator" => "timber", "count" => 10 }],
         "max_product" => [{ "identificator" => "timber", "count" => 10 }] }]
    end
    plant_type
  end

  factory :plant_place, class: "Shared::PlantPlace" do
    name { "Место" }
    plant_category factory: :plant_category_processing
  end

  factory :plant, class: "Shared::Plant" do
    plant_level
    plant_place
    economic_subject_type { "Guild" }
    association :economic_subject, factory: :guild
    params { { "produced" => [] } }
  end
end
