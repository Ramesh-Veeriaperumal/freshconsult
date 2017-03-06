require_relative '../unit_test_helper'

class AgentValidationTest < ActionView::TestCase
  def tear_down
    Account.unstub(:current)
    super
  end

  def test_valid
    Account.stubs(:current).returns(Account.new)
    agent_item = Agent.new
    agent_item.user = User.new
    agent = AgentValidation.new({ name: Faker::Name.name, phone: Faker::PhoneNumber.phone_number, mobile: Faker::PhoneNumber.phone_number, email: Faker::Internet.email, time_zone: 'Central Time (US & Canada)', language: 'hu', occasional: false, signature: Faker::Lorem.paragraph, ticket_scope: 2,
                                  role_ids: [1, 2, 3], group_ids: [1, 2, 3], job_title: Faker::Name.name }, agent_item, false)
    assert agent.valid?
  end

  def test_invalid
    Account.stubs(:current).returns(Account.new)
    agent_item = Agent.new
    agent_item.user = User.new
    agent = AgentValidation.new({ name: nil, phone: 3_534_653, mobile: 6_756_868, email: Faker::Name.name, time_zone: 'Cntral Time (US & Canada)', language: 'huty', occasional: 'yes', signature: 123, ticket_scope: 212, role_ids: ['test', 'y'], group_ids: ['test', 'y'], job_title: 234 }, agent_item, false)
    refute agent.valid?
    errors = agent.errors.sort.to_h
    error_options = agent.error_options.sort.to_h
    assert_equal({ email: :invalid_format, group_ids: :array_datatype_mismatch, job_title: :datatype_mismatch, language: :not_included, mobile: :datatype_mismatch, name: :datatype_mismatch, occasional: :datatype_mismatch, phone: :datatype_mismatch, role_ids: :array_datatype_mismatch, signature: :datatype_mismatch, ticket_scope: :not_included, time_zone: :not_included }, errors)
    assert_equal({ email: { accepted: :"valid email address" }, group_ids: { expected_data_type: :"Positive Integer", code: :datatype_mismatch }, job_title: { expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer }, language: { list: I18n.available_locales.map(&:to_s).join(',') }, mobile: { expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer }, name: { expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Null' }, occasional: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String }, phone: { expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer }, role_ids: { expected_data_type: :"Positive Integer", code: :datatype_mismatch }, signature: { expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer }, ticket_scope: { list: '1,2,3' }, time_zone: { list: "American Samoa,International Date Line West,Midway Island,Hawaii,Alaska,Pacific Time (US & Canada),Tijuana,Arizona,Chihuahua,Mazatlan,Mountain Time (US & Canada),Central America,Central Time (US & Canada),Guadalajara,Mexico City,Monterrey,Saskatchewan,Bogota,Eastern Time (US & Canada),Indiana (East),Lima,Quito,Atlantic Time (Canada),Caracas,Georgetown,La Paz,Santiago,Newfoundland,Brasilia,Buenos Aires,Greenland,Mid-Atlantic,Azores,Cape Verde Is.,Casablanca,Dublin,Edinburgh,Lisbon,London,Monrovia,UTC,Amsterdam,Belgrade,Berlin,Bern,Bratislava,Brussels,Budapest,Copenhagen,Ljubljana,Madrid,Paris,Prague,Rome,Sarajevo,Skopje,Stockholm,Vienna,Warsaw,West Central Africa,Zagreb,Athens,Bucharest,Cairo,Harare,Helsinki,Istanbul,Jerusalem,Kyiv,Pretoria,Riga,Sofia,Tallinn,Vilnius,Baghdad,Kuwait,Minsk,Moscow,Nairobi,Riyadh,St. Petersburg,Volgograd,Tehran,Abu Dhabi,Baku,Muscat,Tbilisi,Yerevan,Kabul,Ekaterinburg,Islamabad,Karachi,Tashkent,Chennai,Kolkata,Mumbai,New Delhi,Sri Jayawardenepura,Kathmandu,Almaty,Astana,Dhaka,Urumqi,Rangoon,Bangkok,Hanoi,Jakarta,Krasnoyarsk,Novosibirsk,Beijing,Chongqing,Hong Kong,Irkutsk,Kuala Lumpur,Perth,Singapore,Taipei,Ulaan Bataar,Osaka,Sapporo,Seoul,Tokyo,Yakutsk,Adelaide,Darwin,Brisbane,Canberra,Guam,Hobart,Melbourne,Port Moresby,Sydney,Vladivostok,Magadan,New Caledonia,Solomon Is.,Auckland,Fiji,Kamchatka,Marshall Is.,Wellington,Nuku'alofa,Samoa,Tokelau Is." } }, error_options)
  end

  def test_agent_with_blank_mandatory_fields
    Account.stubs(:current).returns(Account.new)
    agent_item = Agent.new
    agent_item.user = User.new
    agent = AgentValidation.new({ name: '', email: '', time_zone: '', language: '', occasional: nil, ticket_scope: nil,
                                  role_ids: [] }, agent_item, false)
    refute agent.valid?
    errors = agent.errors.sort.to_h
    error_options = agent.error_options.sort.to_h
    assert_equal({ email: :blank, language: :not_included, name: :blank, occasional: :datatype_mismatch, role_ids: :blank, ticket_scope: :not_included, time_zone: :not_included }, errors)
    assert_equal({ email: { expected_data_type: String }, language: { list: I18n.available_locales.map(&:to_s).join(',') }, name: { expected_data_type: String }, occasional: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: 'Null' },  role_ids: {}, ticket_scope: { list: '1,2,3' }, time_zone: { list: "American Samoa,International Date Line West,Midway Island,Hawaii,Alaska,Pacific Time (US & Canada),Tijuana,Arizona,Chihuahua,Mazatlan,Mountain Time (US & Canada),Central America,Central Time (US & Canada),Guadalajara,Mexico City,Monterrey,Saskatchewan,Bogota,Eastern Time (US & Canada),Indiana (East),Lima,Quito,Atlantic Time (Canada),Caracas,Georgetown,La Paz,Santiago,Newfoundland,Brasilia,Buenos Aires,Greenland,Mid-Atlantic,Azores,Cape Verde Is.,Casablanca,Dublin,Edinburgh,Lisbon,London,Monrovia,UTC,Amsterdam,Belgrade,Berlin,Bern,Bratislava,Brussels,Budapest,Copenhagen,Ljubljana,Madrid,Paris,Prague,Rome,Sarajevo,Skopje,Stockholm,Vienna,Warsaw,West Central Africa,Zagreb,Athens,Bucharest,Cairo,Harare,Helsinki,Istanbul,Jerusalem,Kyiv,Pretoria,Riga,Sofia,Tallinn,Vilnius,Baghdad,Kuwait,Minsk,Moscow,Nairobi,Riyadh,St. Petersburg,Volgograd,Tehran,Abu Dhabi,Baku,Muscat,Tbilisi,Yerevan,Kabul,Ekaterinburg,Islamabad,Karachi,Tashkent,Chennai,Kolkata,Mumbai,New Delhi,Sri Jayawardenepura,Kathmandu,Almaty,Astana,Dhaka,Urumqi,Rangoon,Bangkok,Hanoi,Jakarta,Krasnoyarsk,Novosibirsk,Beijing,Chongqing,Hong Kong,Irkutsk,Kuala Lumpur,Perth,Singapore,Taipei,Ulaan Bataar,Osaka,Sapporo,Seoul,Tokyo,Yakutsk,Adelaide,Darwin,Brisbane,Canberra,Guam,Hobart,Melbourne,Port Moresby,Sydney,Vladivostok,Magadan,New Caledonia,Solomon Is.,Auckland,Fiji,Kamchatka,Marshall Is.,Wellington,Nuku'alofa,Samoa,Tokelau Is." } }, error_options)
  end

  def test_agent_with_length_valid
    Account.stubs(:current).returns(Account.new)
    agent_item = Agent.new
    agent_item.user = User.new
    agent = AgentValidation.new({ name: Faker::Lorem.characters(300), job_title: Faker::Lorem.characters(300), mobile: Faker::Lorem.characters(300),
                                  email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(300)}.com", phone: Faker::Lorem.characters(300) }, agent_item, false)
    refute agent.valid?
    errors = agent.errors.sort.to_h
    error_options = agent.error_options.sort.to_h
    assert_equal({ email: :too_long, job_title: :too_long, mobile: :too_long, name: :too_long, phone: :too_long, role_ids: :blank, time_zone: :not_included }, errors)
    assert_equal({ email: { max_count: 255, current_count: 328, element_type: :characters, min_count: 0 }, job_title: { min_count: 0, max_count: 255, current_count: 300, element_type: :characters }, language: {}, mobile: { min_count: 0, max_count: 255, current_count: 300, element_type: :characters }, name: { min_count: 0, max_count: 255, current_count: 300, element_type: :characters }, phone: { min_count: 0, max_count: 255, current_count: 300, element_type: :characters }, role_ids: {}, time_zone: { list: "American Samoa,International Date Line West,Midway Island,Hawaii,Alaska,Pacific Time (US & Canada),Tijuana,Arizona,Chihuahua,Mazatlan,Mountain Time (US & Canada),Central America,Central Time (US & Canada),Guadalajara,Mexico City,Monterrey,Saskatchewan,Bogota,Eastern Time (US & Canada),Indiana (East),Lima,Quito,Atlantic Time (Canada),Caracas,Georgetown,La Paz,Santiago,Newfoundland,Brasilia,Buenos Aires,Greenland,Mid-Atlantic,Azores,Cape Verde Is.,Casablanca,Dublin,Edinburgh,Lisbon,London,Monrovia,UTC,Amsterdam,Belgrade,Berlin,Bern,Bratislava,Brussels,Budapest,Copenhagen,Ljubljana,Madrid,Paris,Prague,Rome,Sarajevo,Skopje,Stockholm,Vienna,Warsaw,West Central Africa,Zagreb,Athens,Bucharest,Cairo,Harare,Helsinki,Istanbul,Jerusalem,Kyiv,Pretoria,Riga,Sofia,Tallinn,Vilnius,Baghdad,Kuwait,Minsk,Moscow,Nairobi,Riyadh,St. Petersburg,Volgograd,Tehran,Abu Dhabi,Baku,Muscat,Tbilisi,Yerevan,Kabul,Ekaterinburg,Islamabad,Karachi,Tashkent,Chennai,Kolkata,Mumbai,New Delhi,Sri Jayawardenepura,Kathmandu,Almaty,Astana,Dhaka,Urumqi,Rangoon,Bangkok,Hanoi,Jakarta,Krasnoyarsk,Novosibirsk,Beijing,Chongqing,Hong Kong,Irkutsk,Kuala Lumpur,Perth,Singapore,Taipei,Ulaan Bataar,Osaka,Sapporo,Seoul,Tokyo,Yakutsk,Adelaide,Darwin,Brisbane,Canberra,Guam,Hobart,Melbourne,Port Moresby,Sydney,Vladivostok,Magadan,New Caledonia,Solomon Is.,Auckland,Fiji,Kamchatka,Marshall Is.,Wellington,Nuku'alofa,Samoa,Tokelau Is." } }, error_options)
  end
end
