# frozen_string_literal: true

class OperationSerializer
  def self.serialize(op, detailed: false)
    return nil if op.nil?
    base = {
      id: op.id,
      kind: op.kind,
      year: op.year,
      status: op.status == 1 ? "applied" : "reverted",
      subject: "#{op.subject_type}##{op.subject_id}",
      comment: op.comment,
      meta: op.meta,
      created_at: op.created_at
    }
    base[:initiator] = op.initiator&.display_name
    base[:items] = op.operation_items.map do |i|
      { identificator: i.identificator, name: i.name, delta: i.delta,
        is_card: i.is_card, card_kind: i.card_kind }
    end
    base[:ref] = "#{op.ref_type}##{op.ref_id}" if op.ref_type
    base
  end

  def self.serialize_list(ops)
    ops.map { |op| serialize(op) }
  end
end
