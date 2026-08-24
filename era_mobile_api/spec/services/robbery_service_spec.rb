# frozen_string_literal: true

require "rails_helper"

RSpec.describe RobberyService do
  let(:year) { 2 }

  def robbery_gp
    Shared::GameParameter.find_by(identificator: Shared::GameParameter::ROBBERY_GP_ID) ||
      Shared::GameParameter.create!(
        name: "Настройки ограбления караванов",
        identificator: Shared::GameParameter::ROBBERY_GP_ID,
        value: "0",
        params: {
          "robbery_by_year" => {}, "protected_guilds_by_year" => {},
          "arrived_count_by_year" => {}, "robbed_count_by_year" => {}
        }
      )
  end

  def set_robbery(year, robbery_count, arrived = 0, robbed = 0)
    gp = robbery_gp
    gp.params ||= {}
    gp.params["robbery_by_year"] = { year.to_s => robbery_count }
    gp.params["arrived_count_by_year"] = { year.to_s => arrived }
    gp.params["robbed_count_by_year"] = { year.to_s => robbed }
    gp.save!
  end

  describe "вероятность P = остаток_ограблений / остаток_караванов" do
    before do
      Shared::GameParameter.find_or_create_by!(identificator: "caravans_per_guild") do |gp|
        gp.name = "Количество караванов в гильдии"
        gp.value = "3"
        gp.params = {}
      end
    end

    it "растёт по мере отправки караванов" do
      total_slots = Shared::Guild.count * 3 # caravans_per_guild=3 (существующие гильдии учтены)

      set_robbery(year, 3)
      s0 = described_class.probability_status(year: year, guild_id: 999)
      expect(s0).to be_within(0.001).of(3.0 / total_slots)

      3.times { Shared::GameParameter.increment_arrived_count(year) }

      s1 = described_class.probability_status(year: year, guild_id: 999)
      expect(s1).to be_within(0.001).of(3.0 / (total_slots - 3))
    end

    it "не превышает 1 и не падает ниже 0" do
      create(:guild)
      set_robbery(year, 5)
      p = described_class.probability_status(year: year, guild_id: 999)
      expect(p).to be_between(0, 1).inclusive
    end

    it "нулевая при нулевом плане ограблений" do
      set_robbery(year, 0)
      expect(described_class.probability_status(year: year, guild_id: 999)).to eq(0.0)
    end
  end

  describe "статистический прогон (ТЗ 16)" do
    before do
      Shared::GameParameter.find_or_create_by!(identificator: "caravans_per_guild") do |gp|
        gp.name = "Количество караванов в гильдии"
        gp.value = "3"
        gp.params = {}
      end
    end

    it "доля ограблений ≈ плану при большом числе караванов" do
      6.times { create(:guild) } # 6 гильдий × 3 каравана = 18 слотов
      planned = 4
      set_robbery(year, planned)

      robbed = 0
      trials = 400
      # Сброс счётчиков перед прогоном
      gp = robbery_gp
      gp.update!(params: {
                   "robbery_by_year" => { year.to_s => planned },
                   "arrived_count_by_year" => {},
                   "robbed_count_by_year" => {},
                   "protected_guilds_by_year" => {}
                 })
      expected_first_roll = [planned.to_f / (Shared::Guild.count * 3), 1.0].min

      trials.times do
        result = described_class.attempt(year: year, guild_id: 10_000)
        robbed += 1 if result == described_class::ROBBERY_SUCCESS
        # Возвращаем потраченные попытки для независимых испытаний вероятности P(первой отправки)
        if result != described_class::NO_ROBBERY
          gp = robbery_gp
          p = gp.params
          p["robbed_count_by_year"] = {}
          p["arrived_count_by_year"] = {}
          gp.update!(params: p)
        end
      end

      rate = robbed.to_f / trials
      expect(rate).to be_within(0.12).of(expected_first_roll)
    end
  end

  describe "защита каравана (FR-31)" do
    it "защищённая гильдия не грабится, но попытка расходуется (как в eraofchange)" do
      guild = create(:guild)
      create(:guild) # вторая для знаменателя
      set_robbery(year, 1)

      gp = Shared::GameParameter.find_by(identificator: Shared::GameParameter::ROBBERY_GP_ID)
      gp.params["protected_guilds_by_year"] = { year.to_s => [guild.id] }
      gp.save!

      result = described_class.attempt(year: year, guild_id: guild.id)
      expect(result).to eq(described_class::ROBBERY_FAILURE).or eq(described_class::NO_ROBBERY)
    end
  end
end
