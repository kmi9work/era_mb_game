# frozen_string_literal: true

class Shared::Guild < ApplicationRecord
  self.table_name = "guilds"

  has_many :players, class_name: "Shared::Player"
  has_many :resource_items, as: :economic_subject, inverse_of: :economic_subject,
                            class_name: "Shared::ResourceItem"
  has_many :plants, as: :economic_subject, inverse_of: :economic_subject,
                    class_name: "Shared::Plant"

  def name_or_default
    name.presence || "Гильдия ##{id}"
  end

  def storage
    Shared::Player::StorageRef.new("Guild", id)
  end

  # Флаг «Защита каравана» на год (FR-31): eraofchange хранит в
  # GameParameter caravan_robbery_settings.protected_guilds_by_year.
  def caravan_protected?(year)
    protected_ids(year).include?(id)
  end

  def protected_ids(year)
    gp = Shared::GameParameter.find_by(identificator: "caravan_robbery_settings")
    (gp&.params&.dig("protected_guilds_by_year") || {})[year.to_s].to_a.map(&:to_i)
  end
end
