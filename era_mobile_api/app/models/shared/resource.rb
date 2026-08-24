# frozen_string_literal: true

# Справочник ресурсов eraofchange:
# params.sale_price — рынок покупает у игрока; params.buy_price — рынок продаёт игроку.
# Ключи цен — уровни отношений -2..2 (в JSON это строки).
class Shared::Resource < ApplicationRecord
  self.table_name = "resources"

  belongs_to :country, optional: true, class_name: "Shared::Country"

  scope :for_country, ->(country_id) { where(country_id: country_id) }

  def sale_price_for(relation)
    price_list.dig("sale_price", relation.to_s)
  end

  def buy_price_for(relation)
    price_list.dig("buy_price", relation.to_s)
  end

  private

  def price_list
    params || {}
  end
end
