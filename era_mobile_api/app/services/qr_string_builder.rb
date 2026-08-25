# frozen_string_literal: true

# Единый формат QR-строки игрока — как на странице era_front /players:
#   {"type":"player_auth","identificator":"<код>","player_name":"...","generated_at":"..."}
module QrStringBuilder
  module_function

  def build(player)
    {
      type: "player_auth",
      identificator: player.identificator,
      player_name: player.display_name,
      generated_at: Time.current.iso8601
    }.to_json
  end
end
