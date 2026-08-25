# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth API", type: :request do
  let(:player) { create(:player) }
  let!(:qr_string) { QrStringBuilder.build(player) }

  describe "POST /auth/login" do
    it "логинит по QR era_front и возвращает токен" do
      post "/auth/login", params: { qr_string: qr_string, device_info: "test" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["token"]).to be_present
      expect(body["player"]["id"]).to eq(player.id)
    end

    it "401 на QR с неизвестным identificator" do
      post "/auth/login", params: { qr_string: { type: "player_auth", identificator: "NOPE-000" }.to_json }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "Bearer-аутентификация API" do
    it "401 без токена" do
      get "/api/v1/lobby"
      expect(response).to have_http_status(:unauthorized)
    end

    it "200 с валидным токеном" do
      login = AuthService.login(qr_string: qr_string)
      get "/api/v1/lobby", headers: { Authorization: "Bearer #{login.token}" }
      expect(response).to have_http_status(:ok)
    end
  end
end
