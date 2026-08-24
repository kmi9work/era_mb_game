# frozen_string_literal: true

# Карточка — предмет хранилища (FR-33). Автоэффекты v1 (FR-34):
# contraband (контрабанда) и caravan_protection (защита каравана).
class Mb::Card < ApplicationRecord
  self.table_name = "mb_cards"

  # Владелец хранится как "Guild"/"Player" (типы eraofchange); резолвим в Shared::*.
  def owner
    case owner_type
    when "Guild" then Shared::Guild.find_by(id: owner_id)
    when "Player" then Shared::Player.find_by(id: owner_id)
    end
  end

  def owner=(obj)
    self.owner_type = obj.class.name.split("::").last
    self.owner_id = obj.id
  end

  enum status: { in_stock: 0, used: 1, transferred_away: 2 }

  CARD_KINDS = {
    "contraband" => "Контрабанда",
    "caravan_protection" => "Защита каравана"
  }.freeze

  TYPE_MAP = { "Shared::Guild" => "Guild", "Guild" => "Guild",
               "Shared::Player" => "Player", "Player" => "Player" }.freeze

  scope :stock_of, lambda { |owner|
    type = TYPE_MAP.fetch(owner.class.name, owner.class.name.split("::").last)
    where(owner_type: type, owner_id: owner.id, status: :in_stock)
  }
  scope :of_kind, ->(kind) { where(card_kind: kind) }

  def display_name
    political_action_type_action.presence || CARD_KINDS[card_kind] || card_kind
  end

  def self.take_card!(owner:, kind:, consumed_by: nil)
    transaction do
      card = stock_of(owner).lock.where(card_kind: kind).order(:created_at).first
      raise ActiveRecord::RecordNotFound, "Нет карточки «#{CARD_KINDS[kind] || kind}» в хранилище" unless card

      attrs = {}
      if consumed_by
        attrs[:consumed_by_type] = consumed_by.class.name
        attrs[:consumed_by_id] = consumed_by.id
      end
      card.update!(attrs.merge(status: consumed_by ? :used : :transferred_away))
      card
    end
  end
end
