# frozen_string_literal: true

# Общая сущность eraofchange. Схему меняем только в репозитории eraofchange (ТЗ 5.1).
class Shared::Player < ApplicationRecord
  self.table_name = "players"

  belongs_to :guild, optional: true, class_name: "Shared::Guild"
  has_many :mb_sessions, class_name: "Mb::Session", foreign_key: :player_id
  has_and_belongs_to_many :jobs, join_table: "jobs_players", class_name: "Shared::Job"
  has_many :resource_items, as: :economic_subject, inverse_of: :economic_subject,
                            class_name: "Shared::ResourceItem"
  has_many :plants, as: :economic_subject, inverse_of: :economic_subject,
                    class_name: "Shared::Plant"

  validates :name, presence: { message: "Поле Имя должно быть заполнено" }
  validates :identificator, presence: true, uniqueness: true

  StorageRef = Struct.new(:type, :id) do
    def to_s
      "#{type}##{id}"
    end
  end

  def storage
    StorageRef.new("Player", id)
  end

  # Хранилище купца из гильдии — казна гильдии (ТЗ 6.3)
  def effective_storage(scenario = nil)
    if guild_id && scenario&.flag?("guild_owns_member_property")
      guild.storage
    else
      storage
    end
  end

  def display_name
    name.presence || "Игрок ##{id}"
  end

  def guild_boss?
    job_ids.include?(1) # Job «Глава гульдии» в eraofchange (id 1)
  end
end
