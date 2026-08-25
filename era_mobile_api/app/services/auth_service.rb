# frozen_string_literal: true

# Вход по QR (FR-2..FR-5): сканирование персонального кода → сессия с Bearer-токеном.
#
# Источник QR — страница era_front «Игроки и QR-коды» (/players): она генерирует
# коды в браузере из общей базы игроков. Формат:
#   {"type":"player_auth","identificator":"F119BA8FB8C8B26B","player_name":"...","generated_at":"..."}
# Подлинность = наличие такого identificator в таблице players (единая база с eraofchange,
# ТЗ 5.1). Смена identificator мастером в era_front мгновенно делает старый бейдж
# недействительным — отдельный выпуск/отзыв токенов не нужен.
class AuthService
  Result = Struct.new(:ok, :token, :player, :error, keyword_init: true)

  def self.login(qr_string:, device_info: nil)
    identificator = extract_identificator(qr_string)
    return Result.new(ok: false, error: "Неверный формат QR-кода") if identificator.blank?

    player = Shared::Player.find_by(identificator: identificator)
    return Result.new(ok: false, error: "Игрок не найден. Обратитесь к мастеру") if player.nil?

    open_session!(player, device_info: device_info)
  rescue StandardError => e
    Rails.logger.error("[Auth] login failed: #{e.class}: #{e.message}")
    Result.new(ok: false, error: "Ошибка входа, попробуйте ещё раз")
  end

  # Принимаем JSON из era_front, а также «голый» идентификатор (ручной ввод/резервный путь)
  def self.extract_identificator(qr_string)
    text = qr_string.to_s.strip
    return nil if text.blank?

    payload = JSON.parse(text)
    ident = payload["identificator"].to_s.strip
    ident.present? ? ident : nil
  rescue JSON::ParserError
    text
  end

  def self.open_session!(player, device_info:)
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
  end
end
