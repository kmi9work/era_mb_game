# frozen_string_literal: true

class Shared::Country < ApplicationRecord
  self.table_name = "countries"

  has_many :relation_items, class_name: "Shared::RelationItem"
  has_many :resources, class_name: "Shared::Resource"
  has_many :regions, class_name: "Shared::Region"
  has_many :caravans, class_name: "Shared::Caravan"

  REL_RANGE = 2

  def embargo?
    params&.dig("embargo").to_i == 1 || params&.dig("embargo") == true
  end

  # Текущие отношения — сумма relation_items, клэмп в [-2..2]
  def relations
    sum = relation_items.sum(&:value).to_i
    sum.clamp(-REL_RANGE, REL_RANGE)
  end

  # FR-25: цены страны по текущим отношениям
  def trade_prices
    rel = relations
    resources.where.not(identificator: "gold").order(:name).map do |r|
      {
        identificator: r.identificator,
        name: r.name,
        sale_price: r.sale_price_for(rel),
        buy_price: r.buy_price_for(rel)
      }
    end
  end
end
