# frozen_string_literal: true

# FR-53: разбор совершённой операции компенсирующей транзакцией.
# Прямого редактирования истории нет — только компенсации с пометкой обеих сторон.
class Mb::Operations::Revert
  def self.call!(operation:, master_comment:)
    new(operation, master_comment).call!
  end

  def initialize(operation, master_comment)
    @op = operation
    @comment = master_comment
  end

  def call!
    raise ArgumentError, "Комментарий мастера обязателен" if @comment.blank?
    raise ArgumentError, "Операция уже отменена" if @op.status == 0

    ActiveRecord::Base.transaction do
      subject = StorageRef.new(@op.subject_type, @op.subject_id)
      counterparty = @op.counterparty_id ? StorageRef.new(@op.counterparty_type, @op.counterparty_id) : nil

      entries_subject = []
      entries_counterparty = []

      @op.operation_items.each do |item|
        delta = item.delta
        entries_subject << { identificator: item.identificator, name: item.name, delta: -delta }

        if counterparty && !item.is_card
          mirrored = mirrored_delta(item, delta)
          entries_counterparty << { identificator: item.identificator, name: item.name, delta: mirrored }
        elsif item.is_card && counterparty
          # карточку вернуть владельцу
          entries_counterparty << { identificator: item.identificator, name: item.name,
                                    delta: 1, is_card: true, card_kind: item.card_kind }
          entries_subject << { identificator: item.identificator, name: item.name,
                               delta: -1, is_card: true, card_kind: item.card_kind }
          entries_subject.pop
          entries_subject << { identificator: item.identificator, name: item.name,
                               delta: -delta, is_card: true, card_kind: item.card_kind }
        end
      end

      revert_op = StorageService.create_operation(
        kind: "master_revert",
        initiator: nil, year: Shared::GameParameter.current_year,
        ref: @op, idempotency_key: "revert:#{@op.id}",
        comment: @comment, meta: { reverted_operation_id: @op.id },
        subject: subject, counterparty: counterparty
      )

      apply_entries!(subject, entries_subject, revert_op)
      apply_entries!(counterparty, entries_counterparty, revert_op) if counterparty

      revert_op.update!(status: 1)
      @op.update!(status: 0)

      notify(revert_op)
      revert_op
    end
  end

  StorageRef = Struct.new(:type, :id)

  private

  # Позиции исходной операции — дельты хранилища subject. Для контрагента
  # зеркальные дельты сохранены в meta (см. StorageService.append_counterparty_meta).
  # Компенсация контрагенту: он ПОЛУЧИЛ count позиций — при отборе возвращаем минус.
  def mirrored_delta(item, _delta)
    key = "to_#{@op.counterparty_type}_#{@op.counterparty_id}"
    list = (@op.meta || {})[key] || []
    match = list.find { |m| m["identificator"] == item.identificator }
    received = match ? match["count"].to_i : -item.delta
    -received.abs
  end

  def apply_entries!(storage_ref, entries, revert_op)
    entries.reject { |e| e[:delta].to_i.zero? }.each do |e|
      if e[:is_card]
        StorageService.apply_card_delta_for_revert(owner: StorageService.owner_for(storage_ref),
                                                   entry: e, op: revert_op)
      else
        StorageService.change_resource!(storage: storage_ref, identificator: e[:identificator],
                                        delta: e[:delta])
        revert_op.operation_items.create!(identificator: e[:identificator], name: e[:name],
                                          delta: e[:delta])
      end
    end
  end

  def notify(revert_op)
    players = []
    if @op.subject_type == "Player"
      players << Shared::Player.find_by(id: @op.subject_id)
    elsif @op.subject_type == "Guild"
      players += Shared::Player.where(guild_id: @op.subject_id)
    end
    players.compact.each do |p|
      Mb::Notification.notify!(
        player: p, kind: "master_revert",
        title: "Мастер отменил операцию",
        body: @comment, push: true
      )
    end
  rescue StandardError => e
    Rails.logger.warn("[Revert] notify failed: #{e.message}")
  end
end
