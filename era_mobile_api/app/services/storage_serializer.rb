# frozen_string_literal: true

class StorageSerializer
  def self.balance_full(player:, scenario:)
    storage = player.effective_storage(scenario)
    StorageService.balance(storage).merge(storage_type: storage.type)
  end

  def self.guild_view(player:, scenario:)
    return nil unless player.guild_id
    guild = Shared::Guild.find(player.guild_id)
    balance = StorageService.balance(guild.storage)
    {
      id: guild.id,
      name: guild.name_or_default,
      caravan_protected: guild.caravan_protected?(Shared::GameParameter.current_year),
      balance: balance,
      members: guild.players.select(:id, :name).map { |p| { id: p.id, name: p.display_name } },
      last_operations: OperationSerializer.serialize_list(
        Mb::Operation.for_subject("Guild", guild.id).limit(10)
      )
    }
  end
end
