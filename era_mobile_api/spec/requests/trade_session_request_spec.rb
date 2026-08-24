# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Trade sessions API", type: :request do
  let(:scenario) { Mb::ScenarioConfig.current }
  let(:guild_a) { create(:guild) }
  let(:guild_b) { create(:guild) }
  let(:player_a) { create(:player, guild: guild_a) }
  let(:player_b) { create(:player, guild: guild_b) }
  let!(:token_a) { Mb::IdToken.issue_for!(player_a) }
  let!(:token_b) { Mb::IdToken.issue_for!(player_b) }
  let(:auth_a) { AuthService.login(qr_string: token_a.qr_string) }
  let(:auth_b) { AuthService.login(qr_string: token_b.qr_string) }

  def seed_gold(guild, count)
    item = Shared::ResourceItem.find_or_initialize_by(economic_subject_type: "Guild",
                                                      economic_subject_id: guild.id,
                                                      identificator: "gold")
    item.count = count
    item.save!
  end

  it "полный цикл сделки двух игроков (FR-11..FR-15)" do
    seed_gold(guild_a, 1000)
    seed_gold(guild_b, 500)

    # B должен быть онлайн (активная сессия)
    _ = auth_b

    post "/api/v1/trade_sessions",
         params: { partner_player_id: player_b.id },
         headers: auth_headers(auth_a)
    expect(response).to have_http_status(:ok)
    session_id = JSON.parse(response.body)["id"]

    # Офферы
    post "/api/v1/trade_sessions/#{session_id}/offer",
         params: { money: 300 }, headers: auth_headers(auth_a)
    expect(response).to have_http_status(:ok)

    post "/api/v1/trade_sessions/#{session_id}/offer",
         params: { money: 100 }, headers: auth_headers(auth_b)
    expect(response).to have_http_status(:ok)

    # Подтверждения
    post "/api/v1/trade_sessions/#{session_id}/confirm", headers: auth_headers(auth_a)
    expect(JSON.parse(response.body)["status"]).not_to eq("completed")

    post "/api/v1/trade_sessions/#{session_id}/confirm", headers: auth_headers(auth_b)
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["status"]).to eq("completed")

    gold_a = Shared::ResourceItem.find_by(economic_subject_type: "Guild", economic_subject_id: guild_a.id,
                                          identificator: "gold").count
    gold_b = Shared::ResourceItem.find_by(economic_subject_type: "Guild", economic_subject_id: guild_b.id,
                                          identificator: "gold").count
    expect(gold_a).to eq(1000 - 300 + 100)
    expect(gold_b).to eq(500 - 100 + 300)

    # FR-16: кнопки отмены после исполнения нет — cancel вернёт ошибку/отказ
    delete "/api/v1/trade_sessions/#{session_id}", headers: auth_headers(auth_a)
    expect(response.status).to be_between(400, 499).inclusive
  end

  def auth_headers(auth)
    { Authorization: "Bearer #{auth.token}" }
  end
end
