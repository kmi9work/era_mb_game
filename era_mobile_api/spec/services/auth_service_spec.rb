# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthService do
  let(:player) { create(:player) }
  let!(:token) { Mb::IdToken.issue_for!(player) }

  describe "#login" do
    it "создаёт сессию по валидному QR (FR-2)" do
      result = described_class.login(qr_string: token.qr_string, device_info: "Android/Pixel")

      expect(result.ok).to be(true)
      expect(result.player.id).to eq(player.id)
      expect(result.token).to be_present

      session, found_player = Mb::Session.authenticate(result.token)
      expect(found_player.id).to eq(player.id)
    end

    it "отклоняет подделанный HMAC" do
      payload = JSON.parse(token.qr_string)
      payload["s"] = "deadbeef" * 8
      result = described_class.login(qr_string: JSON.generate(payload))

      expect(result.ok).to be(false)
      expect(result.error).to match(/подпись/i)
    end

    it "отклоняет случайный UUID (подделка невозможна без ключа)" do
      payload = { t: "mb_player_auth", pid: player.id, u: SecureRandom.uuid, s: SecureRandom.hex(32) }
      result = described_class.login(qr_string: JSON.generate(payload))
      expect(result.ok).to be(false)
    end

    it "новый вход ревокует прежнюю сессию (FR-4)" do
      first = described_class.login(qr_string: token.qr_string)
      second = described_class.login(qr_string: token.qr_string)

      expect(first.token).not_to eq(second.token)

      # Старый токен больше не работает
      expect(Mb::Session.authenticate(first.token)).to be_nil
      # Новый активен
      expect(Mb::Session.authenticate(second.token)).not_to be_nil

      active_count = Mb::Session.where(player_id: player.id, status: :active).count
      expect(active_count).to eq(1)
    end

    it "не пускает игрока с отозванным QR" do
      token.update!(status: :revoked)
      result = described_class.login(qr_string: token.qr_string)
      expect(result.ok).to be(false)
    end

    it "ошибка на невалидном JSON" do
      result = described_class.login(qr_string: "не-json")
      expect(result.ok).to be(false)
    end
  end
end
