# frozen_string_literal: true

# Схема мобильной игры. era_mobile_api владеет ТОЛЬКО таблицами с префиксом mb_
# (ТЗ 6.2, правило миграций 5.1). Общие таблицы eraofchange здесь не создаются —
# в dev/test они разворачиваются песочницей lib/tasks/era_sandbox.rake.
class CreateMbSchema < ActiveRecord::Migration[7.0]
  def change
    # ─── FR-2..FR-4: сессии входа, одна активная на игрока ──────────────────
    create_table :mb_sessions do |t|
      t.references :player, null: false, index: true
      t.string  :token_hash, null: false
      t.string  :device_info
      t.integer :status, null: false, default: 0 # 0 active / 1 closed / 2 revoked
      t.datetime :last_seen_at
      t.datetime :closed_at

      t.timestamps
    end
    add_index :mb_sessions, :token_hash, unique: true
    add_index :mb_sessions, [:player_id, :status]

    # ─── FR-11..FR-17: торговые сессии ───────────────────────────────────────
    create_table :mb_trade_sessions do |t|
      t.references :initiator, null: false
      t.references :partner, null: false
      t.integer :status, null: false, default: 0
      # 0 pending / 1 active / 2 completed / 3 cancelled / 4 expired
      t.json    :offers_a, default: {}, null: false # предложение инициатора
      t.json    :offers_b, default: {}, null: false # предложение партнёра
      t.boolean :confirmed_a, null: false, default: false
      t.boolean :confirmed_b, null: false, default: false
      t.datetime :expires_at
      t.datetime :completed_at

      t.timestamps
    end
    add_index :mb_trade_sessions, [:initiator_id, :status]
    add_index :mb_trade_sessions, [:partner_id, :status]

    # ─── 6.4: единый append-only журнал операций ─────────────────────────────
    create_table :mb_operations do |t|
      t.string  :kind, null: false
      # trade / plant_purchase / plant_upgrade / plant_sell / plant_produce /
      # caravan_send / caravan_result / political_action / master_correction /
      # master_revert
      t.integer :year, null: false                 # игровой год
      t.references :initiator                      # player (может быть NULL у мастера)
      t.bigint  :counterparty_id                   # второй player или guild
      t.string  :counterparty_type                 # Player / Guild
      t.string  :subject_type, null: false         # чьё хранилище: Player/Guild
      t.bigint  :subject_id, null: false
      t.string  :ref_type                          # MbTradeSession / CaravanMobile / Plant ...
      t.bigint  :ref_id
      t.string  :idempotency_key
      t.string  :comment                           # для мастерских коррекций обязателен
      t.json    :meta, default: {}, null: false    # детали (уровень, страна, ролл...)
      t.integer :status, null: false, default: 1   # 0 reverted / 1 applied

      t.timestamps
    end
    add_index :mb_operations, :idempotency_key, unique: true
    add_index :mb_operations, [:subject_type, :subject_id, :created_at], name: "idx_mb_ops_subject"
    add_index :mb_operations, [:kind, :year], name: "idx_mb_ops_kind_year"

    create_table :mb_operation_items do |t|
      t.references :operation, null: false, index: true
      t.string  :identificator, null: false        # ресурс или 'money'/'gold'
      t.string  :name                              # человекочитаемое имя ресурса
      t.integer :delta, null: false                # +/- к хранилищу subject операции
      t.string  :card_kind                         # для карточек: contraband/protection/...
      t.boolean :is_card, null: false, default: false

      t.timestamps
    end
    add_index :mb_operation_items, :identificator

    # ─── FR-25..FR-31: заявки караванов мобильной игры ───────────────────────
    create_table :mb_caravans_mobile, id: false do |t|
      t.primary_key :id
      t.references :guild, null: false
      t.references :country, null: false
      t.integer :year, null: false
      t.integer :status, null: false, default: 0
      # 0 in_transit / 1 processed_ok / 2 robbed / 3 cancelled_by_master
      t.json    :sell_items, default: [], null: false   # [{identificator,name,count}]
      t.json    :buy_items,  default: [], null: false
      t.integer :sale_income, null: false, default: 0   # предрасчёт по ценам
      t.integer :purchase_cost, null: false, default: 0
      t.integer :price_basis_year                       # фиксация цен (если при отправке)
      t.float   :roll_probability                       # P на момент регистрации
      t.boolean :precalculated_robbed, null: false, default: false
      t.boolean :contraband_used, null: false, default: false
      t.boolean :protected, null: false, default: false # флаг «Защита каравана»
      t.datetime :sent_at, null: false
      t.datetime :process_at, null: false               # момент обработки джобой
      t.datetime :processed_at

      t.timestamps
    end
    add_index :mb_caravans_mobile, [:guild_id, :country_id, :year]
    add_index :mb_caravans_mobile, :process_at

    # ─── FR-33: карточки как предметы хранилищ ───────────────────────────────
    create_table :mb_cards do |t|
      t.string  :owner_type, null: false            # Player / Guild
      t.bigint  :owner_id, null: false
      t.string  :card_kind, null: false             # contraband / caravan_protection / charity / ...
      t.string  :political_action_type_action       # связь с PAT.action (для отображения)
      t.integer :obtained_year, null: false
      t.integer :status, null: false, default: 0
      # 0 in_stock / 1 used / 2 transferred_away
      t.string  :consumed_by_type                   # что израсходовало (MbCaravanMobile...)
      t.bigint  :consumed_by_id
      t.json    :meta, default: {}, null: false

      t.timestamps
    end
    add_index :mb_cards, [:owner_type, :owner_id, :status]
    add_index :mb_cards, [:owner_type, :owner_id, :card_kind, :status], name: "idx_mb_cards_owner_kind_status"

    # ─── Раздел 12: конфигурация сценария ────────────────────────────────────
    create_table :mb_scenario_configs do |t|
      t.string  :name, null: false                  # "Эра перемен"
      t.boolean :active, null: false, default: false
      t.json    :settings, null: false, default: {}
      # caravan_price_fixing: processing|sending; caravan_process_minutes: N;
      # trade_session_timeout: sec; guild_owns_member_property: bool;
      # starting_money: int; robbery_* и т.д.
      t.timestamps
    end

    # ─── FR-38: push-токены устройств ────────────────────────────────────────
    create_table :mb_push_tokens do |t|
      t.references :player, null: false
      t.string  :platform, null: false              # fcm / apns
      t.string  :token, null: false
      t.datetime :last_seen_at

      t.timestamps
    end
    add_index :mb_push_tokens, [:platform, :token], unique: true

    # ─── FR-38/FR-39: центр уведомлений ──────────────────────────────────────
    create_table :mb_notifications do |t|
      t.references :player, null: false, index: true
      t.string  :kind, null: false
      t.string  :title, null: false
      t.text    :body
      t.json    :payload, default: {}, null: false
      t.boolean :read, null: false, default: false

      t.timestamps
    end
    add_index :mb_notifications, [:player_id, :read, :created_at]
  end
end
