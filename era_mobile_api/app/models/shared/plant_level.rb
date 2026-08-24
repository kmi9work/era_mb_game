# frozen_string_literal: true

class Shared::PlantLevel < ApplicationRecord
  self.table_name = "plant_levels"

  MAX_LEVEL = 3

  belongs_to :plant_type, optional: true, class_name: "Shared::PlantType"
  has_many :plants, class_name: "Shared::Plant"

  # Формат formulas (как в eraofchange):
  # [{"from"=>[{"identificator"=>"grain","count"=>2}],
  #   "to"=>[{"identificator"=>"flour","count"=>1}],
  #   "max_product"=>[{"identificator"=>"flour","count"=>300}]}]
  #
  # Повторяет логику eraofchange PlantLevel#feed_to_plant!: перерабатывает
  # максимум доступного по каждой формуле, не превышая max_product.
  # «Технические училища» дают ×1.5 к выходу.
  def compute_conversion(available_inputs)
    coof = Shared::Technology.open?(Shared::Technology::TECH_SCHOOLS) ? 1.5 : 1.0

    request = Hash.new(0)
    available_inputs.each { |r| request[r[:identificator].to_s] += r[:count].to_i }

    from_total = Hash.new(0)
    to_total = Hash.new(0)

    formulas.each do |formula|
      n = max_runs(formula, request)
      next if n <= 0

      formula["from"].each { |r| from_total[r["identificator"]] += r["count"].to_i * n }
      formula["to"].each   { |r| to_total[r["identificator"]] += r["count"].to_i * n }
      formula["from"].each { |r| request[r["identificator"]] -= r["count"].to_i * n }
    end

    if coof != 1.0 && to_total.any?
      to_total.transform_values! { |v| (v * coof).floor }
    end

    {
      from: from_total.map { |k, v| { identificator: k, count: v } }.select { |r| r[:count].positive? },
      to:   to_total.map { |k, v| { identificator: k, count: v } }.select { |r| r[:count].positive? }
    }
  end

  private

  def max_runs(formula, request)
    per_run_from = formula["from"] || []
    return 1 if per_run_from.empty? # добывающая формула — один прогон в год

    cap_by_input = per_run_from.map do |r|
      have = request[r["identificator"]].to_i
      need = r["count"].to_i
      need.positive? ? have / need : 0
    end.min

    cap_by_max = max_product_runs(formula)

    [cap_by_input, cap_by_max].min
  end

  def max_product_runs(formula)
    maxp = formula["max_product"]
    return Float::INFINITY if maxp.blank?

    caps = formula["to"].map do |out|
      mp = maxp.find { |m| m["identificator"] == out["identificator"] }
      out_count = out["count"].to_i
      out_count.positive? && mp ? mp["count"].to_i / out_count : Float::INFINITY
    end
    caps.min || Float::INFINITY
  end
end
