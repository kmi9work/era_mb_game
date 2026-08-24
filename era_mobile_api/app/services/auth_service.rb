# frozen_string_literal: true

# Вход по QR (FR-2..FR-5): сканирование персонального кода → сессия с Bearer-токеном.
class AuthService
  Result = Struct.new(:ok, :token, :player, :error, keyword_init: true)

  # qr_string — JSON вида {"t":"mb_player_auth","pid":1,"u":<uuid>,"s":<hmac>}
  def self.login(qr_string:, device_info: nil)
    payload = parse_payload(qr_string)
    return Result.new(ok: false, error: "Неверный формат QR-кода") if payload.nil?

    player = Shared::Player.find_by(id: payload["pid"])
    return Result.new(ok: false, error: "Игрок не найден. Обратитесь к мастеру") if player.nil?

    token = Mb::IdToken.active_tokens.find_by(player_id: player.id)
    return Result.new(ok: false, error: "QR-код отозван мастером") if token.nil?

    # Подпись из отсканированного QR сверяется с HMAC(ключ, pid|uuid) и с хранящимся дайджестом
    provided_signature = payload["s"].to_s
    expected = Mb::IdToken.signature(player.id, payload["u"].to_s)

    unless ActiveSupport::SecurityUtils.secure_compare(provided_signature, expected) &&
           ActiveSupport::SecurityUtils.secure_compare(token.secret_digest.to_s, expected)
      return Result.new(ok: false, error: "Подпись QR-кода не совпадает")
    end

    unless token.public_id == payload["u"].to_s
      return Result.new(ok: false, error: "QR-код устарел")
    end

    # FR-4: новый вход ревокует прежнюю активную сессию; старому устройству — «сессия завершена».
    previous = Mb::Session.where(player_id: player.id, status: :active).first
    session = Mb::Session.open_for!(player, device_info: device_info)

    if previous
      Mb::Notification.notify!(
        player: player,
        kind: "session_revoked",
        title: "Сессия завершена",
        body: "Выполнен вход с нового устройства",
        push: true
      )
      CableBroadcast.session_revoked(previous)
    end

    raw = SecureRandom.hex(24)
    session.update_column(:token_hash, Mb::Session.digest_for(raw))

    Result.new(ok: true, token: raw, player: player)
  rescue StandardError => e
    Rails.logger.error("[Auth] login failed: #{e.class}: #{e.message}")
    Result.new(ok: false, error: "Ошибка входа, попробуйте ещё раз")
  end

  def self.parse_payload(qr_string)
    JSON.parse(qr_string.to_s)
  rescue JSON::ParserError
    nil
  end
end
