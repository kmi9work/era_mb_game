# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin API", type: :request do
  let(:master_headers) { { "X-Master-Key" => ENV.fetch("MB_MASTER_KEY", "dev-master-key") } }

  describe "FR-50 игроки и доступ" do
    it "возвращает список игроков" do
      create(:player)
      get "/admin_api/players", headers: master_headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["players"].size).to be >= 1
    end

    it "требует мастер-ключ" do
      get "/admin_api/players", headers: { "X-Master-Key" => "wrong" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "FR-52 коррекции" do
    let(:guild) { create(:guild) }

    def seed_gold(count)
      item = Shared::ResourceItem.find_or_initialize_by(economic_subject_type: "Guild",
                                                        economic_subject_id: guild.id,
                                                        identificator: "gold")
      item.count = count
      item.save!
    end

    it "начисляет ресурсы с обязательным комментарием" do
      seed_gold(0)
      post "/admin_api/corrections", params: {
        subject_type: "Guild", subject_id: guild.id,
        comment: "Компенсация за утерянный жетон",
        entries: [{ identificator: "gold", delta: 500 }]
      }, headers: master_headers, as: :json

      expect(response).to have_http_status(:ok)
      gold = Shared::ResourceItem.find_by(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                          identificator: "gold")
      expect(gold.count).to eq(500)

      op = Mb::Operation.applied.order(:created_at).last
      expect(op.kind).to eq("master_correction")
      expect(op.comment).to include("жетон")
    end

    it "отказ без комментария" do
      post "/admin_api/corrections", params: {
        subject_type: "Guild", subject_id: guild.id,
        comment: "",
        entries: [{ identificator: "gold", delta: 1 }]
      }, headers: master_headers, as: :json
      expect(response).to have_http_status(422)
    end
  end

  describe "FR-53 отмена операции компенсирующей транзакцией" do
    let(:guild_a) { create(:guild) }
    let(:guild_b) { create(:guild) }

    def gold_of(guild)
      Shared::ResourceItem.find_by(economic_subject_type: "Guild", economic_subject_id: guild.id,
                                   identificator: "gold")&.count || 0
    end

    def set_gold(guild, count)
      item = Shared::ResourceItem.find_or_initialize_by(economic_subject_type: "Guild",
                                                        economic_subject_id: guild.id,
                                                        identificator: "gold")
      item.count = count
      item.save!
    end

    it "разбирает перевод возвратом позиций обеим сторонам" do
      set_gold(guild_a, 1000)
      set_gold(guild_b, 0)

      op = StorageService.transfer!(
        from: Shared::Player::StorageRef.new("Guild", guild_a.id),
        to: Shared::Player::StorageRef.new("Guild", guild_b.id),
        items: [{ identificator: "gold", name: "Золото", count: 400 }],
        kind: "trade"
      )

      post "/admin_api/operations/#{op.id}/revert", params: { comment: "Ошибка сделки" },
           headers: master_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(gold_of(guild_a)).to eq(1000)
      expect(gold_of(guild_b)).to eq(0)

      # Исходная операция помечена отменённой; в журнале — компенсация
      expect(op.reload.status).to eq(0)
      compensation = Mb::Operation.where(kind: "master_revert").order(:created_at).last
      expect(compensation.comment).to eq("Ошибка сделки")
    end
  end

  describe "FR-54 караваны мастера" do
    it "показывает предрасчёт исхода сразу" do
      guild = create(:guild)
      country = create(:country)
      caravan = Mb::CaravanMobile.create!(
        guild_id: guild.id, country_id: country.id, year: 1,
        sell_items: [{ identificator: "timber", name: "Брёвна", count: 10 }],
        buy_items: [], sale_income: 100, purchase_cost: 0,
        precalculated_robbed: true, sent_at: Time.current, process_at: Time.current + 5.minutes
      )

      get "/admin_api/caravans", headers: master_headers
      body = JSON.parse(response.body)["caravans"]
      target = body.find { |c| c["id"] == caravan.id }
      expect(target["precalculated_robbed"]).to be(true)
    end
  end

  describe "FR-56 мониторинг целостности" do
    it "отдаёт сводку без расхождений по построению" do
      get "/admin_api/integrity_check", headers: master_headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["ok"]).to be(true)
      expect(body).to have_key("resources")
      expect(body).to have_key("operations_total")
    end
  end
end
