# frozen_string_literal: true

# FR-40: любая ошибка — человекочитаемый текст с причиной.
module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :internal_error
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid do |e|
      render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  private

  def not_found(e)
    render json: { error: "Не найдено: #{e.message}" }, status: :not_found
  end

  def internal_error(e)
    Rails.logger.error("[#{e.class}] #{e.message}\n#{e.backtrace.first(8).join("\n")}")
    render json: { error: "Внутренняя ошибка сервера. Повторите запрос" }, status: :internal_server_error
  end
end
