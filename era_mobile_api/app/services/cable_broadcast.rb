# frozen_string_literal: true

# Обёртка над ActionCable-рассылками (ТЗ 5.1: realtime для лобби и торговых сессий).
module CableBroadcast
  CHANNEL = "player_channel"

  module_function

  def lobby(player_or_id, payload = {})
    id = player_or_id.is_a?(Shared::Player) ? player_or_id.id : player_or_id
    ActionCable.server.broadcast(
      "#{CHANNEL}_#{id}",
      { event: "lobby_update", year: Shared::GameParameter.current_year }.merge(payload)
    )
  rescue StandardError => e
    Rails.logger.warn("[Cable] lobby broadcast failed: #{e.message}")
  end

  def trade_state(session)
    [session.initiator_id, session.partner_id].each do |pid|
      ActionCable.server.broadcast(
        "#{CHANNEL}_#{pid}",
        {
          event: "trade_update",
          trade_session_id: session.id,
          status: session.status,
          your_offer_confirmed: nil
        }
      )
    end
  rescue StandardError => e
    Rails.logger.warn("[Cable] trade broadcast failed: #{e.message}")
  end

  def trade_invite(session, from_player, to_player)
    ActionCable.server.broadcast(
      "#{CHANNEL}_#{to_player.id}",
      {
        event: "trade_invite",
        trade_session_id: session.id,
        from: from_player.display_name
      }
    )
  rescue StandardError => e
    Rails.logger.warn("[Cable] invite failed: #{e.message}")
  end

  def session_revoked(session)
    ActionCable.server.broadcast(
      "#{CHANNEL}_#{session.player_id}",
      { event: "session_revoked", reason: "Вход с другого устройства" }
    )
  rescue StandardError => e
    Rails.logger.warn("[Cable] revoke broadcast failed: #{e.message}")
  end

  def balance_changed(player_or_storage)
    storage = player_or_storage
    ids = if storage.type == "Guild"
            Shared::Player.where(guild_id: storage.id).pluck(:id)
          else
            [storage.id]
          end
    ids.each { |pid| lobby(pid, event: "lobby_update", reason: "balance") }
  end
end
