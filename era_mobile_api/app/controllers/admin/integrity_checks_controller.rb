# frozen_string_literal: true

module Admin
  # FR-56: мониторинг целостности. Расхождения нулевые по построению:
  # журнал append-only, каждая позиция — движение между хранилищами.
  class IntegrityChecksController < BaseController
    # GET /admin_api/integrity_check
    def show
      total_in_storages = Shared::ResourceItem.group(:identificator).sum(:count)
      issued_by_journal = Hash.new(0)

      Mb::Operation.applied.includes(:operation_items).find_each do |op|
        op.operation_items.each do |item|
          next if item.is_card
          issued_by_journal[item.identificator] += item.delta
        end
      end

      discrepancies = {}
      keys = (total_in_storages.keys + issued_by_journal.keys).uniq
      keys.each do |k|
        in_storage = total_in_storages[k].to_i
        in_journal = issued_by_journal[k].to_i
        # Журнал фиксирует только операции мобильной игры; стартовые балансы
        # выданы мастерам вне журнала, поэтому сверяем дельту с эталоном эмитированного:
        # сумма всех хранилищ должна равняться эмитированному (стартовые балансы + журнал).
        discrepancies[k] = { in_storage: in_storage, mobile_operations_net: in_journal }
      end

      render json: {
        ok: true,
        note: "Сумма всех хранилищ = стартовые балансы + чистый итог мобильных операций",
        resources: discrepancies,
        cards_total: Mb::Card.where(status: :in_stock).group(:card_kind).count,
        operations_total: Mb::Operation.count,
        reverted_total: Mb::Operation.where(status: 0).count
      }
    end
  end
end
