# frozen_string_literal: true

# Демо-данные для разработки (гильдии, игроки, ресурсы, предприятия, технологии).
# Не для продакшена: прод-справочники приходят из общей базы eraofchange.
#
#   bundle exec rails runner "load(Rails.root.join('db/demo_seeds.rb'))"

ActiveRecord::Base.transaction do
  # ─── Гильдии ────────────────────────────────────────────────────────────────
  guilds = ["Забавники", "Каменщики", "Пивовары"].map do |name|
    Shared::Guild.find_or_create_by!(name: name) { |g| g.params = {} }
  end

  # ─── Игроки (по 3 купца на гильдию; первый — глава) ─────────────────────────
  job_boss = Shared::Job.find_or_create_by!(name: "Глава гульдии")
  job_merchant = Shared::Job.find_or_create_by!(name: "Купец")

  players = []
  guilds.each_with_index do |guild, gi|
    ["Иван", "Пётр", "Фёдор"].each_with_index do |first_name, pi|
      name = "#{first_name} #{['Смолин','Кузнецов','Веселов'][gi]} #{pi + 1}"
      player = Shared::Player.find_or_create_by!(identificator: "DEMO_#{gi}_#{pi}") do |p|
        p.name = name
        p.guild = guild
      end
      unless player.job_ids.include?(pi.zero? ? job_boss.id : job_merchant.id)
        player.job_ids += [pi.zero? ? job_boss.id : job_merchant.id]
        player.save!
      end
      players << player
    end
  end

  # ─── Стартовые балансы казны гильдий (правило: собственность членов — гильдии) ───
  scenario = Mb::ScenarioConfig.current
  starting_money = scenario.setting("starting_money")
  guilds.each do |g|
    next if Shared::ResourceItem.exists?(economic_subject_type: "Guild", economic_subject_id: g.id)
    Shared::ResourceItem.create!(
      economic_subject_type: "Guild", economic_subject_id: g.id,
      identificator: StorageService::MONEY_ID, count: starting_money
    )
  end

  # ─── Технологии (закрыты) ────────────────────────────────────────────────────
  tech_names = {
    Shared::Technology::RURAL_SCHOOLS => "Сельские школы",
    Shared::Technology::ST_GEORGE_DAY => "Георгиев день",
    Shared::Technology::CRAFTSMEN => "Ремесловые люди",
    Shared::Technology::TECH_SCHOOLS => "Технические училища",
    Shared::Technology::OVERSEAS_TRADE => "Заморская торговля"
  }
  tech_names.each do |id, name|
    t = Shared::Technology.find_by(id: id)
    next if t
    t = Shared::Technology.create!(name: name, description: name, params: { "opened" => 0 })
    t.technology_items.create!(value: 0, year: 1, comment: "seed")
  end

  # ─── Страны, регионы, залежи ────────────────────────────────────────────────
  rus = Shared::Country.find_by(name: "Русь") || Shared::Country.create!(name: "Русь", short_name: "Русь", params: {})
  foreign = [
    ["Большая Орда", "Орда"], ["Ливонский орден", "Ливония"], ["Королевство Швеция", "Швеция"],
    ["Великое княжество Литовское", "Литва"], ["Казанское ханство", "Казань"], ["Крымское ханство", "Крым"]
  ]
  countries = foreign.map do |full, short|
    Shared::Country.find_by(name: full) || Shared::Country.create!(name: full, short_name: short, params: {})
  end

  regions = ["Великое Московское княжество", "Вологодская земля", "Нижегородская земля", "Ярославское княжество"].map do |rname|
    r = Shared::Region.find_by(name: rname)
    r || Shared::Region.create!(name: rname, country: rus, params: {})
  end

  dob = Shared::PlantCategory.find_or_create_by!(name: "Добывающее") { |c| c.is_extractive = true }
  per = Shared::PlantCategory.find_or_create_by!(name: "Перерабатывающее") { |c| c.is_extractive = false }

  fossils = {}
  ["Строевой лес", "Пастбище", "Плодородная земля", "Камень", "Железная руда", "Драгоценная руда"].each do |fname|
    fossils[fname] = Shared::FossilType.find_by(name: fname) || Shared::FossilType.create!(name: fname)
  end

  # Места: переработка — во всех регионах; добыча леса/камня — в первых четырёх
  per_place = Shared::PlantPlace.find_or_create_by!(plant_category: per, region: regions.first) do |pp|
    pp.name = "Место для перерабатывающих предприятий"
  end
  extractive_places = regions.map do |r|
    pp = Shared::PlantPlace.find_or_create_by!(plant_category: dob, region: r) do |place|
      place.name = "Место для добывающих предприятий в #{r.name}"
    end
    pp.fossil_types |= [fossils["Строевой лес"], fossils["Камень"], fossils["Плодородная земля"]]
    pp
  end

  # ─── Типы и уровни предприятий (из 5_economics.rb) ──────────────────────────
  delyan = Shared::PlantType.find_or_create_by!(id: 1) do |pt|
    pt.name = "Делянка"; pt.plant_category = dob; pt.fossil_type = fossils["Строевой лес"]
  end
  quarry_t = Shared::PlantType.find_or_create_by!(id: 4) do |pt|
    pt.name = "Каменоломня"; pt.plant_category = dob; pt.fossil_type = fossils["Камень"]
  end
  saw_mill = Shared::PlantType.find_or_create_by!(id: 7) do |pt|
    pt.name = "Лесопилка"; pt.plant_category = per
  end
  stonemason = Shared::PlantType.find_or_create_by!(id: 8) do |pt|
    pt.name = "Мастерская каменотёса"; pt.plant_category = per
  end

  seed_levels = lambda { |type_id, levels|
    levels.each do |lvl, deposit, price, formulas|
      next if Shared::PlantLevel.exists?(plant_type_id: type_id, level: lvl)
      Shared::PlantLevel.create!(level: lvl, deposit: deposit, price: price, formulas: formulas, plant_type_id: type_id)
    end
  }

  seed_levels.call(delyan.id, [
    [1, 1000, { "timber" => 200, "grain" => 150 },
     [{ "from" => [], "to" => [{ "identificator" => "timber", "count" => 100 }],
        "max_product" => [{ "identificator" => "timber", "count" => 100 }] }]],
    [2, 1700, { "timber" => 50, "grain" => 150 },
     [{ "from" => [], "to" => [{ "identificator" => "timber", "count" => 200 }],
        "max_product" => [{ "identificator" => "timber", "count" => 200 }] }]],
    [3, 4100, { "timber" => 50, "grain" => 200, "tools" => 30 },
     [{ "from" => [], "to" => [{ "identificator" => "timber", "count" => 500 }],
        "max_product" => [{ "identificator" => "timber", "count" => 500 }] }]]
  ])

  seed_levels.call(quarry_t.id, [
    [1, 1200, { "stone" => 120, "timber" => 30 },
     [{ "from" => [], "to" => [{ "identificator" => "stone", "count" => 60 }],
        "max_product" => [{ "identificator" => "stone", "count" => 60 }] }]],
    [2, 2000, { "stone" => 30, "timber" => 30 },
     [{ "from" => [], "to" => [{ "identificator" => "stone", "count" => 120 }],
        "max_product" => [{ "identificator" => "stone", "count" => 120 }] }]],
    [3, 3400, { "stone" => 40, "timber" => 50, "food" => 15 },
     [{ "from" => [], "to" => [{ "identificator" => "stone", "count" => 300 }],
        "max_product" => [{ "identificator" => "stone", "count" => 300 }] }]]
  ])

  seed_levels.call(saw_mill.id, [
    [1, 1000, { "gold" => 1200 },
     [{ "from" => [{ "identificator" => "timber", "count" => 2 }],
        "to" => [{ "identificator" => "boards", "count" => 3 }],
        "max_product" => [{ "identificator" => "boards", "count" => 300 }] }]],
    [2, 2200, { "stone_brick" => 100, "food" => 10 },
     [{ "from" => [{ "identificator" => "timber", "count" => 1 }],
        "to" => [{ "identificator" => "boards", "count" => 2 }],
        "max_product" => [{ "identificator" => "boards", "count" => 600 }] }]],
    [3, 5100, { "stone_brick" => 200, "food" => 30 },
     [{ "from" => [{ "identificator" => "timber", "count" => 1 }],
        "to" => [{ "identificator" => "boards", "count" => 3 }],
        "max_product" => [{ "identificator" => "boards", "count" => 1500 }] }]]
  ])

  seed_levels.call(stonemason.id, [
    [1, 1000, { "gold" => 1200 },
     [{ "from" => [{ "identificator" => "stone", "count" => 1 }],
        "to" => [{ "identificator" => "stone_brick", "count" => 2 }],
        "max_product" => [{ "identificator" => "stone_brick", "count" => 240 }] }]],
    [2, 2400, { "flour" => 150, "metal" => 40 },
     [{ "from" => [{ "identificator" => "stone", "count" => 1 }],
        "to" => [{ "identificator" => "stone_brick", "count" => 3 }],
        "max_product" => [{ "identificator" => "stone_brick", "count" => 540 }] }]],
    [3, 6100, { "flour" => 200, "metal" => 130 },
     [{ "from" => [{ "identificator" => "stone", "count" => 1 }],
        "to" => [{ "identificator" => "stone_brick", "count" => 4 }],
        "max_product" => [{ "identificator" => "stone_brick", "count" => 1200 }] }]]
  ])

  # ─── Ресурсы и цены стран (матрица по отношениям -2..2) ─────────────────────
  prices = lambda { |sale, buy| { "sale_price" => sale, "buy_price" => buy } }

  country_res = {
    countries[0] => [ # Большая Орда
      ["Лошади", "horses", prices.call({ "-2" => 127, "-1" => 109, "0" => 91, "1" => 91, "2" => 90 },
                                       { "-2" => 51, "-1" => 58, "0" => 64, "1" => 70, "2" => 75 })],
      ["Роскошь", "luxury", prices.call({ "-2" => 1000, "-1" => 860, "0" => 700, "1" => 700, "2" => 700 },
                                        { "-2" => 400, "-1" => 450, "0" => 500, "1" => 550, "2" => 600 })]
    ],
    countries[1] => [ # Ливонский орден
      ["Каменный кирпич", "stone_brick", prices.call({ "-2" => 21, "-1" => 18, "0" => 15, "1" => 15, "2" => 15 },
                                                     { "-2" => 9, "-1" => 10, "0" => 11, "1" => 12, "2" => 13 })],
      ["Камень", "stone", prices.call({ "-2" => 28, "-1" => 24, "0" => 20, "1" => 20, "2" => 20 },
                                      { "-2" => 11, "-1" => 13, "0" => 14, "1" => 15, "2" => 17 })],
      ["Доспехи", "armor", prices.call({ "-2" => 860, "-1" => 740, "0" => 615, "1" => 615, "2" => 615 },
                                       { "-2" => 350, "-1" => 390, "0" => 430, "1" => 475, "2" => 520 })]
    ],
    countries[2] => [ # Швеция
      ["Драгоценный металл", "gems", prices.call({ "-2" => nil, "-1" => nil, "0" => nil, "1" => nil, "2" => nil },
                                                 { "-2" => 77, "-1" => 86, "0" => 96, "1" => 106, "2" => 115 })]
    ],
    countries[3] => [ # Литва
      ["Инструменты", "tools", prices.call({ "-2" => 186, "-1" => 160, "0" => 133, "1" => 133, "2" => 130 },
                                           { "-2" => 74, "-1" => 84, "0" => 93, "1" => 102, "2" => 110 })],
      ["Бревна", "timber", prices.call({ "-2" => 14, "-1" => 12, "0" => 10, "1" => 10, "2" => 10 },
                                       { "-2" => 6, "-1" => 6, "0" => 7, "1" => 8, "2" => 8 })],
      ["Доски", "boards", prices.call({ "-2" => 13, "-1" => 11, "0" => 9, "1" => 9, "2" => 9 },
                                      { "-2" => 6, "-1" => 6, "0" => 7, "1" => 8, "2" => 8 })]
    ],
    countries[4] => [ # Казань
      ["Железная руда", "metal_ore", prices.call({ "-2" => 10, "-1" => 8, "0" => 7, "1" => 7, "2" => 7 },
                                                 { "-2" => 4, "-1" => 5, "0" => 5, "1" => 6, "2" => 6 })],
      ["Мясо", "meat", prices.call({ "-2" => 27, "-1" => 23, "0" => 19, "1" => 19, "2" => 20 },
                                   { "-2" => 10, "-1" => 12, "0" => 13, "1" => 14, "2" => 15 })],
      ["Провизия", "food", prices.call({ "-2" => 136, "-1" => 116, "0" => 97, "1" => 97, "2" => 100 },
                                       { "-2" => 54, "-1" => 61, "0" => 68, "1" => 75, "2" => 80 })]
    ],
    countries[5] => [ # Крым
      ["Зерно", "grain", prices.call({ "-2" => 4, "-1" => 4, "0" => 3, "1" => 3, "2" => 3 },
                                     { "-2" => 2, "-1" => 2, "0" => 2, "1" => 2, "2" => 2 })],
      ["Мука", "flour", prices.call({ "-2" => 21, "-1" => 18, "0" => 15, "1" => 15, "2" => 15 },
                                    { "-2" => 8, "-1" => 9, "0" => 10, "1" => 11, "2" => 12 })],
      ["Оружие", "weapon", prices.call({ "-2" => 286, "-1" => 245, "0" => 204, "1" => 204, "2" => 200 },
                                       { "-2" => 114, "-1" => 129, "0" => 143, "1" => 157, "2" => 170 })]
    ]
  }

  country_res.each do |country, resources|
    resources.each do |name, ident, params|
      next if Shared::Resource.exists?(identificator: ident, country_id: country.id)
      Shared::Resource.create!(name: name, identificator: ident, country_id: country.id, params: params)
    end
  end

  # Русские ресурсы (для продажи рынком без страны)
  [["Бревна", "timber"], ["Камень", "stone"], ["Зерно", "grain"]].each do |name, ident|
    next if Shared::Resource.exists?(identificator: ident, country_id: nil)
    Shared::Resource.create!(name: name, identificator: ident, country_id: nil, params: prices.call({}, {}))
  end

  # Отношения стран к Руси — нейтральные (0)
  countries.each do |c|
    next if Shared::RelationItem.where(country_id: c.id).exists?
    Shared::RelationItem.create!(value: 0, country_id: c.id, comment: "Стартовые нейтральные отношения", year: 1)
  end

  # Эмбарго Орды для демо контрабанды
  horde = countries[0]
  horde.update!(params: (horde.params || {}).merge("embargo" => 1))

  # ─── Политдействия купцов (pat_merchants.csv) ────────────────────────────────
  boss_job_id = job_boss.id
  pats = [
    ["Подстрекательство к бунту", "sedition", 1500, "8-20"],
    ["Благотворительность", "charity", 2000, "-"],
    ["Саботаж", "sabotage", 4000, "14-20"],
    ["Контрабанда", "contraband", 1000, "6-20"],
    ["Открыть ворота!", "open_gate", 5000, "15-20"],
    ["Новые промыслы", "new_fisheries", 2500, "10-20"],
    ["Народная поддержка", "people_support", 0, "6-20"]
  ]
  pats.each do |name, action, cost, prob|
    next if Shared::PoliticalActionType.exists?(action: action)
    Shared::PoliticalActionType.create!(
      name: name, action: action, icon: "mdi-star", job_id: boss_job_id,
      description: name, cost: cost.to_s, probability: prob, success: ""
    )
  end

  puts "Demo seeds: #{Shared::Player.count} игроков, #{Shared::Guild.count} гильдий, #{Shared::Country.count} стран."
end
