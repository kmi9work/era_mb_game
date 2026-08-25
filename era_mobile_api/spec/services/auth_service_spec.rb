# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthService do
  let(:player) { create(:player) }

  def front_qr(p)
    QrStringBuilder.build(p)
  end

  describe "#login" do
    it "создаёт сессию по QR из era_front (FR-2)" do
      result = described_class.login(qr_string: front_qr(player), device_info: "Android/Pixel")

      expect(result.ok).to be(true)
      expect(result.player.id).to eq(player.id)
      expect(result.token).to be_present

      session, found_player = Mb::Session.authenticate(result.token)
      expect(found_player.id).to eq(player.id)
    end

    it "логинит по «голому» идентификатору без JSON" do
      result = described_class.login(qr_string: " #{player.identificator} ")
      expect(result.ok).to be(true)
      expect(result.player.id).to eq(player.id)
    end

    it "отклоняет неизвестный identificator" do
      result = described_class.login(qr_string: front_qr(build(:player)))
      expect(result.ok).to be(false)
      expect(result.error).to match(/мастеру/i)
    end

    it "новый вход ревокует прежнюю сессию (FR-4)" do
      first = described_class.login(qr_string: front_qr(player))
      second = described_class.login(qr_string: front_qr(player))

      expect(first.token).not_to eq(second.token)

      # Старый токен больше не работает
      expect(Mb::Session.authenticate(first.token)).to be_nil
      # Новый активен
      expect(Mb::Session.authenticate(second.token)).not_to be_nil

      active_count = Mb::Session.where(player_id: player.id, status: :active).count
      expect(active_count).to eq(1)
    end

    it "ошибка на невалидном JSON без идентификатора" do
      result = described_class.login(qr_string: "{\"type\":\"bad\"}")
      expect(result.ok).to be(false)
    end
  end
end
