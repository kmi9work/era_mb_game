# frozen_string_literal: true

# Отложенная обработка каравана в момент T (ТЗ 5.1, FR-28).
class CaravanProcessJob < ApplicationJob
  queue_as :caravans

  def perform(caravan_id)
    caravan = Mb::CaravanMobile.find_by(id: caravan_id)
    return if caravan.nil? || !caravan.in_transit?

    # Дожидаемся момента обработки (джоба ставится на process_at через set)
    CaravanService.process!(caravan)
  end
end
