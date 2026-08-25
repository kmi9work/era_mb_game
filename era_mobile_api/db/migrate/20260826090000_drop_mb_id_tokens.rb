# frozen_string_literal: true

# QR теперь генерирует era_front (/players) из identificator игрока — общей таблицы.
# Подписные токены (UUID + HMAC) больше не используются; таблица удаляется вместе
# с данными. См. AuthService#extract_identificator.
class DropMbIdTokens < ActiveRecord::Migration[7.0]
  def change
    drop_table :mb_id_tokens do |t|
      t.references :player, null: false, index: true
      t.string  :public_id, null: false
      t.string  :secret_digest, null: false
      t.string  :payload_digest, null: false
      t.integer :status, null: false, default: 0
      t.datetime :revoked_at

      t.timestamps
    end
  end
end
