# frozen_string_literal: true

# Торговая сессия по QR (FR-11..FR-18).
class Mb::TradeSession < ApplicationRecord
  self.table_name = "mb_trade_sessions"

  belongs_to :initiator, class_name: "Shared::Player"
  belongs_to :partner, class_name: "Shared::Player"

  enum status: {
    pending: 0,    # создана, ждёт второго игрока
    active: 1,     # экран торговли открыт у обоих
    completed: 2,
    cancelled: 3,
    expired: 4     # автозакрытие по таймауту неактивности (FR-17)
  }

  TIMEOUT = 120 # сек; перекрывается настройкой сценария trade_session_timeout_seconds

  validate :players_differ
  validate :neither_in_active_session, on: :create

  scope :live_of, lambda { |player|
    where("(initiator_id = :p OR partner_id = :p) AND status IN (0,1)", p: player.id)
  }
  scope :stale, -> { where("status IN (0,1) AND updated_at < ?", timeout.ago) }

  def self.timeout
    Mb::ScenarioConfig.current.setting("trade_session_timeout_seconds") || TIMEOUT
  rescue StandardError
    TIMEOUT
  end

  # FR-11: A сканирует B → создать сессию. Проверки занятости — в валидациях.
  def self.start!(initiator:, partner:)
    create!(initiator_id: initiator.id, partner_id: partner.id, status: :active)
  end

  def offer_for(player)
    role_of(player) == :a ? offers_a : offers_b
  end

  def confirmed_for?(player)
    role_of(player) == :a ? confirmed_a : confirmed_b
  end

  def other(player)
    role_of(player) == :a ? partner : initiator
  end

  def role_of(player)
    return :a if player.id == initiator_id
    return :b if player.id == partner_id
    nil
  end

  # FR-13: собрать/изменить своё предложение. Пока обе стороны не подтвердили — можно менять.
  # Если партнёр уже зафиксировал свою часть — правка сбрасывает его подтверждение (FR-14).
  def set_offer!(player, items)
    with_lock do
      return false unless pending? || active?

      reset_other_confirmation(player)
      col = role_of(player) == :a ? :offers_a : :offers_b
      update!(col => normalize(items))
      true
    end
  end

  # FR-14/FR-15: двустороннее подтверждение → атомарное исполнение.
  def confirm!(player)
    lock! # SELECT FOR UPDATE + reload свежих флагов

    return [false, "Сделка уже завершена", nil] unless pending? || active?

    if role_of(player) == :a
      update!(confirmed_a: true)
    else
      update!(confirmed_b: true)
    end

    if confirmed_a? && confirmed_b?
      result = Mb::Trades::Execute.call!(session: self)
      if result.error
        return [false, result.error, nil]
      end
      return [true, nil, result.operations&.first]
    end
    [true, nil, nil]
  end

  def cancel!
    with_lock do
      return false if completed?
      update!(status: :cancelled)
    end
  end

  # FR-17: подвешенные сессии закрываются по таймауту, имущество не движется.
  def self.expire_stale!
    stale.find_each do |s|
      s.update!(status: :expired)
      CableBroadcast.trade_state(s)
    rescue StandardError => e
      Rails.logger.warn("[TradeSession] expire #{s.id}: #{e.message}")
    end
  end

  private

  # Правка своей части снимает оба подтверждения: сделка фиксируется заново (FR-14).
  def reset_other_confirmation(player)
    updates = {}
    updates[:confirmed_a] = false if confirmed_a?
    updates[:confirmed_b] = false if confirmed_b?
    update_columns(updates) if updates.any?
  end

  def normalize(items)
    items = items.each_with_object({}) { |v, h| h[v[0].to_s] = v[1] } if items.is_a?(Hash)

    resources = Array(items["resources"]).map do |r|
      r = r.each_with_object({}) { |v, h| h[v[0].to_sym] = v[1] } if r.is_a?(Hash)
      {
        identificator: r[:identificator].to_s,
        count: r[:count].to_i,
        name: r[:name].to_s
      }
    end.select { |r| r[:count].positive? }

    {
      money: items["money"].to_i,
      resources: resources,
      cards: Array(items["cards"]).map(&:to_i).reject(&:zero?)
    }
  end

  def players_differ
    errors.add(:partner, "нельзя торговать с самим собой") if initiator_id == partner_id
  end

  def neither_in_active_session
    clash = Mb::TradeSession.where(status: [Mb::TradeSession.statuses[:pending], Mb::TradeSession.statuses[:active]])
                            .where("initiator_id IN (:a, :b) OR partner_id IN (:a, :b)",
                                   a: initiator_id, b: partner_id)
    errors.add(:base, "Один из участников уже находится в активной торговой сессии") if clash.exists?
  end
end
