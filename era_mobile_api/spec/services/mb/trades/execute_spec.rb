# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mb::Trades::Execute do
  let(:scenario) { Mb::ScenarioConfig.current }
  let(:guild_a) { create(:guild) }
  let(:guild_b) { create(:guild) }
  let(:player_a) { create(:player, guild: guild_a) }
  let(:player_b) { create(:player, guild: guild_b) }

  def seed_gold(guild_id, count)
    Shared::ResourceItem.find_or_create_by!(economic_subject_type: "Guild", economic_subject_id: guild_id,
                                            identificator: "gold") do |ri|
      ri.count = 0
    end
    item = Shared::ResourceItem.find_by(economic_subject_type: "Guild", economic_subject_id: guild_id,
                                        identificator: "gold")
    item.update!(count: count)
  end

  def gold_of(guild_id)
    Shared::ResourceItem.find_by(economic_subject_type: "Guild", economic_subject_id: guild_id,
                                 identificator: "gold")&.count || 0
  end

  before do
    seed_gold(guild_a.id, 1000)
    seed_gold(guild_b.id, 500)
  end

  it "исполняет двустороннюю сделку атомарно (FR-15)" do
    session = Mb::TradeSession.start!(initiator: player_a, partner: player_b)
    session.set_offer!(player_a, { money: 300 })
    session.set_offer!(player_b, { money: 100 })

    ok, error, = session.confirm!(player_a)
    expect(ok).to be(true)
    expect(error).to be_nil

    ok2, error2, operation = session.confirm!(player_b)
    expect(ok2).to be(true)
    expect(error2).to be_nil
    _ = operation

    session.reload
    expect(session).to be_completed
    expect(gold_of(guild_a.id)).to eq(1000 - 300 + 100)
    expect(gold_of(guild_b.id)).to eq(500 - 100 + 300)

    # Журнал обоим участникам (FR-15)
    ops = Mb::Operation.where(ref_type: "Mb::TradeSession", ref_id: session.id)
    expect(ops.count).to eq(2)
  end

  it "не исполняет сделку при недостатке средств у одной из сторон" do
    session = Mb::TradeSession.start!(initiator: player_a, partner: player_b)
    session.set_offer!(player_a, { money: 50 })
    session.set_offer!(player_b, { money: 9999 })

    ok, error, = session.confirm!(player_a)
    expect(ok).to be(true)

    ok2, error2, = session.confirm!(player_b)
    expect(ok2).to be(false)
    expect(error2).to match(/Недостаточно|золота/i)

    session.reload
    expect(session.status).to eq("active")

    # Балансы не изменились
    expect(gold_of(guild_a.id)).to eq(1000)
    expect(gold_of(guild_b.id)).to eq(500)
    # Завершённых операций по ЭТОЙ сессии нет (ТЗ 6.4: ничего не движется при отказе)
    expect(Mb::Operation.where(kind: "trade", ref_type: "Mb::TradeSession",
                               ref_id: session.id, status: 1).exists?).to be false
  end

  it "гонки: игрок не может быть в двух сессиях одновременно (ТЗ 13)" do
    Mb::TradeSession.start!(initiator: player_a, partner: player_b)
    third = create(:player, guild: guild_b)
    seed_gold(guild_b.id, 100)

    expect {
      Mb::TradeSession.create!(initiator_id: player_b.id, partner_id: third.id)
    }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "правка предложения после подтверждения партнёра сбрасывает его подтверждение (FR-14)" do
    session = Mb::TradeSession.start!(initiator: player_a, partner: player_b)
    session.set_offer!(player_a, { money: 10 })
    session.set_offer!(player_b, { money: 20 })

    ok, = session.confirm!(player_b)
    expect(ok).to be(true)
    session.reload
    expect(session.confirmed_b).to be(true)
    expect(session.confirmed_a).to be(false)

    # A правит свою часть → ОБА подтверждения снимаются (сделка фиксируется заново)
    session.set_offer!(player_a, { money: 30 })
    session.reload
    expect(session.confirmed_b).to be(false)

    # Повторное двустороннее подтверждение исполняет сделку
    session.confirm!(player_a)
    ok2, error2, = session.confirm!(player_b)
    expect(error2).to be_nil
    session.reload
    expect(session.status).to eq("completed")
  end

  context "карточки в сделке" do
    it "перемещает карточку между хранилищами (FR-33)" do
      card = Mb::Card.create!(owner_type: "Guild", owner_id: guild_a.id, card_kind: "contraband",
                              political_action_type_action: "Контрабанда", obtained_year: 1)
      session = Mb::TradeSession.start!(initiator: player_a, partner: player_b)
      session.set_offer!(player_a, { cards: [card.id] })

      session.confirm!(player_a)
      ok2, error2, = session.confirm!(player_b)
      _ = ok2
      expect(error2).to be_nil

      card.reload
      expect(card.owner_id).to eq(guild_b.id)
      expect(card.owner_type).to eq("Guild")
      expect(card).to be_in_stock
    end
  end
end
