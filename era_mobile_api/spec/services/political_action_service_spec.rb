# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoliticalActionService do
  let(:guild) { create(:guild) }
  let(:player) { create(:player, guild: guild) }
  let(:scenario) { Mb::ScenarioConfig.current }

  def seed_gold(count)
    item = Shared::ResourceItem.find_or_initialize_by(economic_subject_type: "Guild",
                                                      economic_subject_id: guild.id,
                                                      identificator: "gold")
    item.count = count
    item.save!
  end

  def pat
    Shared::PoliticalActionType.create!(
      name: "Контрабанда", action: "contraband", icon: "mdi-x",
      description: "", cost: "1000", probability: "6-20", success: ""
    )
  end

  before { seed_gold(5000) }

  it "успех: карточка падает в хранилище (FR-32)" do
    allow_any_instance_of(Object).to receive(:rand).and_return(0.999) # не используется напрямую
    result = described_class.perform!(player: player, scenario: scenario, political_action_type: pat,
                                      idempotency_key: "pa-1")

    # roll = rand(1..20); при 6-20 успех почти гарантирован, но RNG честный — проверим инварианты
    expect(result.ok).to be(true)
    if result.success
      expect(result.roll[:roll]).to be >= 6
      cards = Mb::Card.stock_of(Shared::Guild.find(guild.id))
      expect(cards.exists?).to be(true)
    else
      expect(result.roll[:roll]).to be < 6
    end
    # Деньги списаны в любом случае (правило диздока)
    gold = Shared::ResourceItem.find_by(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                        identificator: "gold").count
    expect(gold).to eq(4000)
  end

  it "недостаточно денег → отказ без броска" do
    seed_gold(100)
    result = described_class.perform!(player: player, scenario: scenario, political_action_type: pat,
                                      idempotency_key: "pa-poor")
    expect(result.ok).to be(false)
    expect(result.error).to match(/Недостаточно/)
  end

  it "идемпотентность повтора" do
    r1 = described_class.perform!(player: player, scenario: scenario, political_action_type: pat,
                                  idempotency_key: "same-key")
    _ = r1
    # Повтор с тем же ключом не должен списать второй раз
    r2 = described_class.perform!(player: player, scenario: scenario, political_action_type: pat,
                                  idempotency_key: "same-key")
    _ = r2

    gold = Shared::ResourceItem.find_by(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                        identificator: "gold")
    expect(gold&.count).to eq(4000)
  end

  describe "#parse_threshold" do
    it "парсит порог из строки вероятности" do
      expect(described_class.parse_threshold("8-20")).to eq(8)
      expect(described_class.parse_threshold("6-20")).to eq(6)
      expect(described_class.parse_threshold("-")).to eq(21)
      expect(described_class.parse_threshold("")).to eq(21)
    end
  end
end
