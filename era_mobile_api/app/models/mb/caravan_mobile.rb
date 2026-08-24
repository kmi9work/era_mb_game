# frozen_string_literal: true

# Заявка каравана мобильной игры (FR-25..FR-31).
class Mb::CaravanMobile < ApplicationRecord
  self.table_name = "mb_caravans_mobile"

  belongs_to :guild, class_name: "Shared::Guild"
  belongs_to :country, class_name: "Shared::Country"

  enum status: { in_transit: 0, processed_ok: 1, robbed: 2, cancelled_by_master: 3 }

  scope :in_transit_due, -> { where(status: :in_transit).where("process_at <= ?", Time.current) }
  scope :for_guild_year, ->(guild_id, year) { where(guild_id: guild_id, year: year) }

  # FR-26: один караван в год в одну страну
  validates :country_id, uniqueness: {
    scope: [:guild_id, :year],
    conditions: -> { where.not(status: :cancelled_by_master) },
    message: "караван в эту страну в этом году уже отправлен"
  }

  def execution_amounts(prices_basis:)
    sell = sell_items.map(&:deep_symbolize_keys)
    buy = buy_items.map(&:deep_symbolize_keys)

    if prices_basis == "sending" && price_basis_year.present?
      return { sale_income: sale_income.to_i, purchase_cost: purchase_cost.to_i }
    end

    rel = country.relations
    sale = sell.sum do |r|
      res = Shared::Resource.find_by(identificator: r[:identificator])
      next (res&.sale_price_for(rel) || 0).to_i * r[:count].to_i if res&.country_id.nil? || res.country_id == country.id
      0
    end
    cost = buy.sum do |r|
      res = Shared::Resource.find_by(identificator: r[:identificator])
      next (res&.buy_price_for(rel) || 0).to_i * r[:count].to_i if res&.country_id.nil? || res.country_id == country.id
      0
    end

    { sale_income: sale.to_i, purchase_cost: cost.to_i }
  end
end
