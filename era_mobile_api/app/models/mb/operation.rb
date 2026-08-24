# frozen_string_literal: true

# Append-only журнал операций (ТЗ 6.4). Исправления — только компенсирующие
# операции мастера (master_correction / master_revert).
class Mb::Operation < ApplicationRecord
  self.table_name = "mb_operations"

  KINDS = %w[
    trade plant_purchase plant_upgrade plant_sell plant_produce
    caravan_send caravan_result political_action master_correction master_revert
  ].freeze

  belongs_to :initiator, class_name: "Shared::Player", optional: true
  has_many :operation_items, class_name: "Mb::OperationItem", dependent: :delete_all

  # Ссылка на источник операции (полиморф): Mb::TradeSession / Mb::CaravanMobile / Shared::Plant...
  def ref
    return nil if ref_type.blank?
    klass = ref_type.start_with?("Shared::") ? ref_type.constantize : "Mb::#{ref_type}".safe_constantize || ref_type.constantize
    klass.find_by(id: ref_id)
  rescue NameError
    nil
  end

  scope :applied, -> { where(status: 1) }
  scope :for_subject, ->(type, id) { where(subject_type: type, subject_id: id).order(created_at: :desc) }
  scope :in_year, ->(y) { where(year: y) }
  scope :of_kind, ->(k) { where(kind: k) }

  # FR-53: отмена — только компенсирующей операцией мастера.
  def revert!(master_comment:)
    raise ArgumentError, "Операция уже отменена" if status.zero?

    Mb::Operations::Revert.call!(operation: self, master_comment: master_comment)
  end
end
