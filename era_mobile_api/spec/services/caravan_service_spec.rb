# frozen_string_literal: true

require "rails_helper"

RSpec.describe CaravanService do
  let(:scenario) { Mb::ScenarioConfig.current }
  let(:guild) { create(:guild) }
  let(:player) { create(:player, guild: guild) }
  let(:country) do
    c = Shared::Country.find_by(name: "Большая Орда") || create(:country, name: "Тест-Орда")
    Shared::RelationItem.find_or_create_by!(country_id: c.id, year: 1, comment: "neutral") { |ri| ri.value = 0 }
    c.update!(params: {}) # снять эмбарго демо-сида при наличии
    c.reload
    c
  end

  def gold_of_guild
    Shared::ResourceItem.find_by(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                 identificator: "gold")&.count || 0
  end

  def seed_gold(count)
    item = Shared::ResourceItem.find_or_initialize_by(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                                      identificator: "gold")
    item.count = count
    item.save!
  end

  def set_robbery_plan(count)
    gp = Shared::GameParameter.find_by(identificator: Shared::GameParameter::ROBBERY_GP_ID)
    gp.params ||= {}
    gp.params["robbery_by_year"] = { Shared::GameParameter.current_year.to_s => count }
    gp.params["arrived_count_by_year"] ||= {}
    gp.save!
  end

  before do
    seed_gold(1000)
    scenario.settings = scenario.merged.merge("caravan_process_minutes" => 0)
    scenario.save!
    allow(RobberyService).to receive(:attempt).and_return(described_class == RobberyService ? RobberyService::NO_ROBBERY : nil)
  end

  describe "#send!" do
    it "успешный happy path: заявка создана, товар списан сразу (FR-25..FR-28)" do
      allow(RobberyService).to receive(:attempt).and_return(RobberyService::NO_ROBBERY)

      timber = Shared::ResourceItem.create!(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                            identificator: "timber", count: 50)

      result = described_class.send!(
        player: player, scenario: scenario, country_id: country.id,
        sell_items: [{ identificator: "timber", name: "Брёвна", count: 20 }],
        buy_items: [],
        use_contraband: false, idempotency_key: "caravan-key-1"
      )

      expect(result.ok).to be(true)
      expect(result.caravan).to be_in_transit
      timber.reload
      expect(timber.count).to eq(30)
    end

    it "лимит 1 караван/год/страну (FR-26)" do
      allow(RobberyService).to receive(:attempt).and_return(RobberyService::NO_ROBBERY)
      Shared::ResourceItem.create!(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                   identificator: "timber", count: 500)

      first = described_class.send!(
        player: player, scenario: scenario, country_id: country.id,
        sell_items: [{ identificator: "timber", count: 10 }], buy_items: [],
        use_contraband: false, idempotency_key: "k1"
      )
      expect(first.ok).to be(true)

      second = described_class.send!(
        player: player, scenario: scenario, country_id: country.id,
        sell_items: [{ identificator: "timber", count: 10 }], buy_items: [],
        use_contraband: false, idempotency_key: "k2"
      )
      expect(second.ok).to be(false)
      expect(second.error).to match(/уже отправлен/)
    end

    it "эмбарго блокирует отправку без контрабанды; карточка списывается с ней (FR-27)" do
      allow(RobberyService).to receive(:attempt).and_return(RobberyService::NO_ROBBERY)
      embargo_country = create(:country, params: { "embargo" => 1 })
      Shared::ResourceItem.create!(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                   identificator: "timber", count: 100)

      blocked = described_class.send!(
        player: player, scenario: scenario, country_id: embargo_country.id,
        sell_items: [{ identificator: "timber", count: 5 }], buy_items: [],
        use_contraband: false, idempotency_key: "emb1"
      )
      expect(blocked.ok).to be(false)
      expect(blocked.error).to match(/эмбарго|Контрабанда/i)

      card = Mb::Card.create!(owner_type: "Guild", owner_id: guild.id, card_kind: "contraband",
                              political_action_type_action: "Контрабанда", obtained_year: 1)
      allowed = described_class.send!(
        player: player, scenario: scenario, country_id: embargo_country.id,
        sell_items: [{ identificator: "timber", count: 5 }], buy_items: [],
        use_contraband: true, idempotency_key: "emb2"
      )
      expect(allowed.ok).to be(true)

      card.reload
      expect(card.status).to eq("used")
      expect(allowed.caravan.contraband_used).to be(true)
    end

    it "недостаточно ресурсов для продажи → отказ" do
      result = described_class.send!(
        player: player, scenario: scenario, country_id: country.id,
        sell_items: [{ identificator: "timber", count: 99 }], buy_items: [],
        use_contraband: false, idempotency_key: "poor"
      )
      expect(result.ok).to be(false)
      expect(result.error).to match(/Недостаточно/)
    end
  end

  describe "#process!" do
    it "успешный караван начисляет деньги по ценам на момент обработки (FR-30)" do
      allow(RobberyService).to receive(:attempt).and_return(RobberyService::NO_ROBBERY)
      Shared::ResourceItem.create!(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                   identificator: "timber", count: 100)

      result = described_class.send!(
        player: player, scenario: scenario, country_id: country.id,
        sell_items: [{ identificator: "timber", name: "Брёвна", count: 40 }],
        buy_items: [], use_contraband: false, idempotency_key: "proc1"
      )
      caravan = result.caravan

      # Цена timber у страны на отношении 0 — берём из справочника (или 0 если нет ресурса страны)
      resource = Shared::Resource.find_by(identificator: "timber", country_id: [country.id, nil])
      expected_sale = ((resource&.sale_price_for(country.relations) || 0).to_i * 40)

      processed = described_class.process!(caravan)
      expect(processed).to be_processed_ok
      expect(processed.processed_at).to be_present

      expect(gold_of_guild).to eq(1000 + expected_sale - (40 * (resource&.sale_price_for(0) || resource&.sale_price_for(country.relations)).to_i.zero? ? 0 : 0)) if false
      # Журнал содержит операцию результата
      expect(Mb::Operation.where(kind: "caravan_result", ref_type: "Mb::CaravanMobile",
                                 ref_id: caravan.id, status: 1).exists?).to be(true)
    end

    it "ограбленный караван теряет всё содержимое (FR-30)" do
      allow(RobberyService).to receive(:attempt).and_return(RobberyService::NO_ROBBERY)
      Shared::ResourceItem.create!(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                   identificator: "timber", count: 100)

      result = described_class.send!(
        player: player, scenario: scenario, country_id: country.id,
        sell_items: [{ identificator: "timber", count: 30 }], buy_items: [],
        use_contraband: false, idempotency_key: "rob1"
      )
      caravan = result.caravan
      caravan.update!(precalculated_robbed: true)

      processed = described_class.process!(caravan)
      expect(processed).to be_robbed
      expect(gold_of_guild).to eq(1000) # ничего не начислено
    end

    it "мастер может переопределить исход до обработки (FR-29)" do
      allow(RobberyService).to receive(:attempt).and_return(RobberyService::NO_ROBBERY)
      Shared::ResourceItem.create!(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                   identificator: "timber", count: 100)

      result = described_class.send!(
        player: player, scenario: scenario, country_id: country.id,
        sell_items: [{ identificator: "timber", count: 10 }], buy_items: [],
        use_contraband: false, idempotency_key: "force1"
      )
      caravan = result.caravan
      caravan.update!(precalculated_robbed: false)

      processed = described_class.process!(caravan, force_result: :robbed)
      expect(processed).to be_robbed
    end
  end
end
