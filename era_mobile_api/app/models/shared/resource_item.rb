# frozen_string_literal: true

class Shared::ResourceItem < ApplicationRecord
  self.table_name = "resource_items"

  def economic_subject
    case economic_subject_type
    when "Guild" then Shared::Guild.find_by(id: economic_subject_id)
    when "Player" then Shared::Player.find_by(id: economic_subject_id)
    end
  end

  def economic_subject=(obj)
    self.economic_subject_type = obj.class.name.split("::").last
    self.economic_subject_id = obj.id
  end
end
