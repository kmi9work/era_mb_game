# frozen_string_literal: true

# Личный канал игрока: лобби (год, таймер, баланс) + торговые сессии (FR-9, FR-12).
class PlayerChannel < ApplicationCable::Channel
  def subscribed
    stream_from "player_channel_#{current_player_id}"

    # Мгновенный снапшот при подключении
    player = Shared::Player.find_by(id: current_player_id)
    if player
      cycle = Shared::GameParameter.cycle_state
      transmit(
        event: "lobby_snapshot",
        year: cycle[:year],
        seconds_left: cycle[:seconds_left],
        cycle_item: cycle[:cycle_item]
      )
    end
  rescue StandardError => e
    logger.warn("[PlayerChannel] subscribe failed: #{e.message}")
    reject_subscription
  end

  def unsubscribed
    # cleanup
  end

  # Пинг года/таймера — клиент может дергать для синхронизации
  def sync_lobby
    cycle = Shared::GameParameter.cycle_state
    transmit(event: "lobby_update", year: cycle[:year],
             seconds_left: cycle[:seconds_left], cycle_item: cycle[:cycle_item])
  end
end
