# frozen_string_literal: true

require "rails_helper"

RSpec.describe Shared::PlantLevel do
  let!(:tech_schools) do
    t = Shared::Technology.find_by(id: Shared::Technology::TECH_SCHOOLS) ||
        Shared::Technology.create!(id: Shared::Technology::TECH_SCHOOLS,
                                   name: "Технические училища", params: {})
    t.technology_items.first_or_initialize.tap { |ti| ti.value ||= 0; ti.year ||= 1; ti.comment ||= ""; ti.save! }
    t
  end

  let(:extractive_level) do
    pt = create(:plant_type, plant_category: create(:plant_category_extractive))
    create(:plant_level, plant_type: pt,
                         formulas: [{ "from" => [],
                                      "to" => [{ "identificator" => "timber", "count" => 100 }],
                                      "max_product" => [{ "identificator" => "timber", "count" => 100 }] }])
  end

  let(:processing_level) do
    pt = create(:plant_type)
    create(:plant_level, plant_type: pt,
                         price: { "gold" => 1200 },
                         deposit: 1000,
                         formulas: [{ "from" => [{ "identificator" => "timber", "count" => 2 }],
                                      "to" => [{ "identificator" => "boards", "count" => 3 }],
                                      "max_product" => [{ "identificator" => "boards", "count" => 300 }] }])
  end

  describe "#compute_conversion добывающее" do
    it "один прогон в год независимо от запасов" do
      result = extractive_level.compute_conversion([])
      expect(result[:to]).to contain_exactly(a_hash_including(identificator: "timber", count: 100))
      expect(result[:from]).to be_empty
    end
  end

  describe "#compute_conversion перерабатывающее" do
    it "перерабатывает максимум доступного, не превышая max_product" do
      available = [{ identificator: "timber", count: 250 }]
      result = processing_level.compute_conversion(available)

      # 250 timber / 2 за прогон = 125 прогонов; max_product 300/3 = 100 прогонов → 100
      expect(result[:from]).to contain_exactly(a_hash_including(identificator: "timber", count: 200))
      expect(result[:to]).to contain_exactly(a_hash_including(identificator: "boards", count: 300))
    end

    it "ограничивается входными ресурсами" do
      available = [{ identificator: "timber", count: 7 }]
      result = processing_level.compute_conversion(available)

      expect(result[:from]).to contain_exactly(a_hash_including(identificator: "timber", count: 6))
      expect(result[:to]).to contain_exactly(a_hash_including(identificator: "boards", count: 9))
    end

    context "«Технические училища» ×1.5 (FR-23)" do
      before do
        tech_schools.technology_items.first.update!(value: 1)
      end

      it "увеличивает выход в 1.5 раза" do
        available = [{ identificator: "timber", count: 20 }]
        result = processing_level.compute_conversion(available)

        # 10 прогонов × 3 boards × 1.5 = 45
        expect(result[:to]).to contain_exactly(a_hash_including(identificator: "boards", count: 45))
        expect(result[:from]).to contain_exactly(a_hash_including(identificator: "timber", count: 20))
      end
    end
  end
end
