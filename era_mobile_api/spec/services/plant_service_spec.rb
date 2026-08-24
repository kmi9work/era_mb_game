# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlantService do
  let(:scenario) { Mb::ScenarioConfig.current }
  let(:guild) { create(:guild) }
  let(:player) { create(:player, guild: guild) }
  let(:rus_country) { Shared::Country.find_by(name: "Русь") || create(:country, name: "Тест-Русь") }
  let(:region) do
    r = Shared::Region.find_by(name: "Тестовый регион") || Shared::Region.create!(name: "Тестовый регион", country_id: rus_country.id, params: {})
    r.update!(country_id: rus_country.id)
    r.reload
    r
  end

  def seed_gold(count)
    item = Shared::ResourceItem.find_or_initialize_by(economic_subject_type: "Guild",
                                                      economic_subject_id: guild.id,
                                                      identificator: "gold")
    item.count = count
    item.save!
  end

  def seed_resource(identificator, count)
    item = Shared::ResourceItem.find_or_initialize_by(economic_subject_type: "Guild",
                                                      economic_subject_id: guild.id,
                                                      identificator: identificator)
    item.count = count
    item.save!
  end

  let!(:extractive_type) do
    cat = create(:plant_category_extractive)
    fossil = create(:fossil_type, name: "Тест-лес")
    create(:plant_type, name: "Делянка", plant_category: cat, fossil_type: fossil)
  end

  let!(:place_with_fossil) do
    place = create(:plant_place, name: "Лесное место", plant_category: extractive_type.plant_category, region: region)
    place.fossil_types << extractive_type.fossil_type
    place.reload
  end

  before do
    seed_gold(10_000)
    seed_resource("timber", 200)
    seed_resource("grain", 200)

    [1, 2, 3].each do |lvl|
      next if Shared::PlantLevel.exists?(plant_type_id: extractive_type.id, level: lvl)
      Shared::PlantLevel.create!(
        level: lvl,
        deposit: lvl * 1000,
        price: { "gold" => lvl * 1000 },
        formulas: [{ "from" => [], "to" => [{ "identificator" => "timber", "count" => lvl * 50 }],
                     "max_product" => [{ "identificator" => "timber", "count" => lvl * 50 }] }],
        plant_type_id: extractive_type.id
      )
    end
  end

  describe "#purchase!" do
    it "покупает предприятие уровня 2 с оплатой всех непостроенных уровней одним подтверждением (FR-21)" do
      key = "buy-1"
      plant = described_class.purchase!(
        player: player, scenario: scenario,
        plant_type_id: extractive_type.id, plant_place_id: place_with_fossil.id,
        to_level: 2, idempotency_key: key
      )

      expect(plant.plant_level.level).to eq(2)
      gold = Shared::ResourceItem.find_by(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                          identificator: "gold")
      expect(gold.count).to eq(10_000 - 3000) # уровни 1 + 2

      op = Mb::Operation.applied.find_by(idempotency_key: key)
      expect(op.kind).to eq("plant_purchase")
    end

    it "отказ без залежей нужного типа (FR-20)" do
      wrong_place = create(:plant_place, plant_category: create(:plant_category_extractive), region: region)

      expect {
        described_class.purchase!(
          player: player, scenario: scenario,
          plant_type_id: extractive_type.id, plant_place_id: wrong_place.id,
          to_level: 1, idempotency_key: "buy-bad"
        )
      }.to raise_error(PlantService::RuleError, /залеж/)
    end

    it "отказ при недостатке золота" do
      seed_gold(100)
      expect {
        described_class.purchase!(
          player: player, scenario: scenario,
          plant_type_id: extractive_type.id, plant_place_id: place_with_fossil.id,
          to_level: 1, idempotency_key: "buy-poor"
        )
      }.to raise_error(StorageService::InsufficientFunds)
    end
  end

  describe "#produce!" do
    let(:plant) do
      Shared::Plant.create!(
        plant_level: Shared::PlantLevel.find_by!(plant_type_id: extractive_type.id, level: 1),
        plant_place: place_with_fossil,
        economic_subject_type: "Guild", economic_subject_id: guild.id,
        params: { "produced" => [] },
        created_at: 2.years.ago
      )
    end

    it "производит и пишет отметку о годе (Эк. 4.1)" do
      year = Shared::GameParameter.current_year
      op = described_class.produce!(player: player, scenario: scenario, plant: plant)

      expect(op.kind).to eq("plant_produce")
      plant.reload
      expect(plant.produced_this_year?(year)).to be(true)

      timber = Shared::ResourceItem.find_by(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                            identificator: "timber")
      expect(timber.count).to eq(200 + 50)
    end

    it "повтор в тот же год невозможен (FR-23)" do
      described_class.produce!(player: player, scenario: scenario, plant: plant)
      expect {
        described_class.produce!(player: player, scenario: scenario, plant: plant)
      }.to raise_error(PlantService::RuleError, /уже производило/)
    end

    it "идемпотентен по ключу (повтор запроса при плохой связи не дважды производит)" do
      year = Shared::GameParameter.current_year
      key = "produce:#{plant.id}:#{year}"
      described_class.produce!(player: player, scenario: scenario, plant: plant, idempotency_key: key)
      timber_before = Shared::ResourceItem.find_by(identificator: "timber",
                                                   economic_subject_type: "Guild",
                                                   economic_subject_id: guild.id).count
      begin
        described_class.produce!(player: player, scenario: scenario, plant: plant, idempotency_key: key)
      rescue PlantService::RuleError
        # повторный вызов упал по «уже производило» — это тоже корректная защита
      ensure
        timber_after = Shared::ResourceItem.find_by(identificator: "timber",
                                                    economic_subject_type: "Guild",
                                                    economic_subject_id: guild.id).count
        expect(timber_after).to eq(timber_before)
      end
    end
  end

  describe "#sell!" do
    it "продаёт за залоговую стоимость текущего уровня (FR-22 / Эк. 3.1)" do
      plant = Shared::Plant.create!(
        plant_level: Shared::PlantLevel.find_by!(plant_type_id: extractive_type.id, level: 2),
        plant_place: place_with_fossil,
        economic_subject_type: "Guild", economic_subject_id: guild.id,
        params: { "produced" => [] }
      )

      op = described_class.sell!(player: player, scenario: scenario, plant: plant, idempotency_key: "sell-1")

      expect(op.meta["deposit"]).to eq(2000)
      gold = Shared::ResourceItem.find_by(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                          identificator: "gold")
      expect(gold.count).to eq(10_000 + 2000)
      expect(Shared::Plant.exists?(plant.id)).to be(false)
    end
  end

  describe "#upgrade!" do
    it "требует технологию «Сельские школы»" do
      tech = Shared::Technology.find_by(id: Shared::Technology::RURAL_SCHOOLS) ||
             Shared::Technology.create!(id: Shared::Technology::RURAL_SCHOOLS, name: "Сельские школы", params: {})
      tech.technology_items.first_or_initialize.tap { |ti| ti.value ||= 0; ti.year ||= 1; ti.comment ||= ""; ti.save! }

      plant = Shared::Plant.create!(
        plant_level: Shared::PlantLevel.find_by!(plant_type_id: extractive_type.id, level: 1),
        plant_place: place_with_fossil,
        economic_subject_type: "Guild", economic_subject_id: guild.id,
        params: { "produced" => [] }
      )

      # Технология закрыта → отказ
      expect {
        described_class.upgrade!(player: player, scenario: scenario, plant: plant, to_level: 2,
                                 idempotency_key: "upg-closed")
      }.to raise_error(PlantService::RuleError, /Сельские школы/)

      # Открываем технологию
      ti = tech.technology_items.first
      ti.update!(value: 1)

      described_class.upgrade!(player: player, scenario: scenario, plant: plant, to_level: 2,
                               idempotency_key: "upg-open")
      expect(plant.reload.plant_level.level).to eq(2)
    end
  end
end
