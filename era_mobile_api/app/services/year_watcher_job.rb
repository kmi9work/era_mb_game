# frozen_string_literal: true

# eraofchange пишет год/таймер; era_mobile_api отслеживает их polling-ом БД
# (2–5 сек допустимо по ТЗ 5.1) и рассылает клиентам через PlayerChannel.
class YearWatcherJob < ApplicationJob
  queue_as :watchers

  POLL_SECONDS = 3

  def perform(last_year = nil, last_signature = nil)
    cycle = Shared::GameParameter.cycle_state
    signature = "#{cycle[:year]}|#{cycle[:cycle_item]&.dig('id')}|#{cycle[:seconds_left] ? (cycle[:seconds_left] / 10) : 'x'}"

    if signature != last_signature
      payload = {
        event: "year_tick",
        year: cycle[:year],
        seconds_left: cycle[:seconds_left],
        cycle_item: cycle[:cycle_item]
      }
      ActionCable.server.broadcast("year_channel", payload)

      # Смена года → уведомление всем (FR-38)
      if last_year && cycle[:year] != last_year
        Shared::Player.find_each do |p|
          Mb::Notification.notify!(
            player: p, kind: "year_changed",
            title: "Год #{cycle[:year]}",
            body: "Начался новый игровой год", push: false
          )
        end
      end
    end

    # Самоперепланирование (проще, чем cron, и не требует Redis-расписаний в dev)
    YearWatcherJob.set(wait: POLL_SECONDS.seconds).perform_later(cycle[:year], signature)
  rescue StandardError => e
    Rails.logger.warn("[YearWatcher] #{e.message}")
    YearWatcherJob.set(wait: POLL_SECONDS.seconds).perform_later(last_year, last_signature)
  end
end
