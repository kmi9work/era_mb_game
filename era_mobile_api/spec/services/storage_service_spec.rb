# frozen_string_literal: true

require "rails_helper"

RSpec.describe StorageService do
  let(:guild) { create(:guild) }
  let(:storage) { Shared::Player::StorageRef.new("Guild", guild.id) }
  let(:other_guild) { create(:guild) }
  let(:other_storage) { Shared::Player::StorageRef.new("Guild", other_guild.id) }

  def seed_gold(storage, count)
    Shared::ResourceItem.create!(economic_subject_type: storage.type, economic_subject_id: storage.id,
                                 identificator: "gold", count: count)
  end

  def gold_of(storage)
    Shared::ResourceItem.find_by(economic_subject_type: storage.type, economic_subject_id: storage.id,
                                 identificator: "gold")&.count || 0
  end

  describe "#transfer!" do
    before do
      seed_gold(storage, 1000)
      seed_gold(other_storage, 100)
    end

    it "перемещает золото между хранилищами" do
      described_class.transfer!(
        from: storage, to: other_storage,
        items: [{ identificator: "gold", name: "Золото", count: 300 }],
        kind: "trade"
      )
      expect(gold_of(storage)).to eq(700)
      expect(gold_of(other_storage)).to eq(400)
    end

    it "отклоняет перевод при недостатке средств" do
      expect {
        described_class.transfer!(
          from: storage, to: other_storage,
          items: [{ identificator: "gold", count: 5000 }],
          kind: "trade"
        )
      }.to raise_error(StorageService::InsufficientFunds)

      # Ничего не двинулось
      expect(gold_of(storage)).to eq(1000)
      expect(gold_of(other_storage)).to eq(100)
    end

    it "идемпотентен по ключу" do
      key = "test-key-1"
      op1 = described_class.transfer!(
        from: storage, to: other_storage,
        items: [{ identificator: "gold", count: 100 }],
        kind: "trade", idempotency_key: key
      )
      op2 = described_class.transfer!(
        from: storage, to: other_storage,
        items: [{ identificator: "gold", count: 100 }],
        kind: "trade", idempotency_key: key
      )
      expect(op1.id).to eq(op2.id)
      expect(gold_of(storage)).to eq(900) # списание только один раз
    end

    it "пишет позиции в журнал" do
      op = described_class.transfer!(
        from: storage, to: other_storage,
        items: [{ identificator: "gold", name: "Золото", count: 250 }],
        kind: "trade"
      )
      expect(op.operation_items.count).to eq(1)
      expect(op.operation_items.first.delta).to eq(-250)
      expect(Mb::OperationItem.where(operation_id: op.id).sum(:delta)).to eq(-250)
    end
  end

  describe "#adjust!" do
    before { seed_gold(storage, 500) }

    it "начисляет и списывает в одном хранилище" do
      described_class.adjust!(
        storage: storage,
        entries: [{ identificator: "gold", delta: -200 }, { identificator: "timber", delta: 50 }],
        kind: "plant_produce"
      )
      expect(gold_of(storage)).to eq(300)
      timber = Shared::ResourceItem.find_by(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                            identificator: "timber")
      expect(timber&.count).to eq(50)
    end

    it "не даёт уйти в минус и откатывает всё" do
      expect {
        described_class.adjust!(
          storage: storage,
          entries: [{ identificator: "gold", delta: -600 }, { identificator: "timber", delta: 50 }],
          kind: "plant_produce"
        )
      }.to raise_error(StorageService::InsufficientFunds)

      expect(gold_of(storage)).to eq(500)
      expect(Shared::ResourceItem.where(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                        identificator: "timber").exists?).to be false
    end
  end

  describe "журнал append-only (ТЗ 6.4)" do
    it "операции не удаляются при движениях; исправление — только компенсацией" do
      seed_gold(storage, 100)
      op = described_class.adjust!(storage: storage,
                                   entries: [{ identificator: "gold", delta: -50 }], kind: "master_correction")
      expect {
        described_class.adjust!(storage: storage,
                                entries: [{ identificator: "gold", delta: 30 }], kind: "master_correction")
      }.to change(Mb::Operation, :count).by(1)
      expect(Mb::Operation.exists?(op.id)).to be true
    end
  end
end
