# frozen_string_literal: true

class Shared::Technology < ApplicationRecord
  self.table_name = "technologies"

  has_many :technology_items, class_name: "Shared::TechnologyItem"

  RURAL_SCHOOLS  = 1 # Сельские школы: разрешают апгрейды предприятий
  ST_GEORGE_DAY  = 2
  CRAFTSMEN      = 3 # Ремесловые люди: кузница/ювелирка
  TECH_SCHOOLS   = 4 # Технические училища: выход переработки ×1.5
  GODS_ANOITED   = 5
  MOSCOW_THIRD_ROME = 6
  DEV_BUREAU     = 7
  OVERSEAS_TRADE = 8 # Заморская торговля: игнор эмбарго
  BLACKSMITHING  = 9
  BALLISTICS     = 10
  CANNING        = 11
  FOREIGN_MERCE  = 12

  def is_open
    technology_items.first&.value.to_i == 1
  end

  def self.open?(id)
    find_by(id: id)&.is_open || false
  end

  def self.tech_schools_open?
    open?(TECH_SCHOOLS)
  end
end
