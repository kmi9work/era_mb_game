# frozen_string_literal: true

module PushService
  # FCM HTTP v1 через googleauth. Ключ сервис-аккаунта — ENV FCM_SERVICE_ACCOUNT_JSON.
  module Fcm
    PROJECT_ID = ENV.fetch("FCM_PROJECT_ID", "")
    SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

    module_function

    def deliver(tokens, title:, body:, payload: {})
      return if tokens.empty? || PROJECT_ID.empty?

      token = authorizer.get_access_token.token
      uri = URI("https://fcm.googleapis.com/v1/projects/#{PROJECT_ID}/messages:send")

      tokens.each do |t|
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        req = Net::HTTP::Post.new(uri.path)
        req["Authorization"] = "Bearer #{token}"
        req["Content-Type"] = "application/json"
        req.body = {
          message: {
            token: t,
            notification: { title: title, body: body },
            data: payload.transform_values(&:to_s),
            android: { priority: "high" }
          }
        }.to_json
        http.request(req)
      rescue StandardError => e
        Rails.logger.warn("[Push] fcm token failed: #{e.message}")
      end
    end

    def authorizer
      @authorizer ||= begin
        json = JSON.parse(ENV.fetch("FCM_SERVICE_ACCOUNT_JSON"))
        Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: StringIO.new(JSON.generate(json)),
          scope: SCOPE
        )
      end
    end
  end
end
