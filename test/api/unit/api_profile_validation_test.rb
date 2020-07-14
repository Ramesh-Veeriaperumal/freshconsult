require_relative '../unit_test_helper'

class ApiProfileValidationTest < ActionView::TestCase
  TIME_ZONE_LIST = "American Samoa,International Date Line West,Midway Island,Hawaii,Alaska,Pacific Time (US & Canada),Tijuana,Arizona,Chihuahua,Mazatlan,Mountain Time (US & Canada),Central America,Central Time (US & Canada),Guadalajara,Mexico City,Monterrey,Saskatchewan,Bogota,Eastern Time (US & Canada),Indiana (East),Lima,Quito,Atlantic Time (Canada),Caracas,Georgetown,La Paz,Santiago,Newfoundland,Brasilia,Buenos Aires,Greenland,Mid-Atlantic,Azores,Cape Verde Is.,Casablanca,Dublin,Edinburgh,Lisbon,London,Monrovia,UTC,Amsterdam,Belgrade,Berlin,Bern,Bratislava,Brussels,Budapest,Copenhagen,Ljubljana,Madrid,Paris,Prague,Rome,Sarajevo,Skopje,Stockholm,Vienna,Warsaw,West Central Africa,Zagreb,Athens,Bucharest,Cairo,Harare,Helsinki,Istanbul,Jerusalem,Kyiv,Pretoria,Riga,Sofia,Tallinn,Vilnius,Baghdad,Kuwait,Minsk,Moscow,Nairobi,Riyadh,St. Petersburg,Volgograd,Tehran,Abu Dhabi,Baku,Muscat,Tbilisi,Yerevan,Kabul,Ekaterinburg,Islamabad,Karachi,Tashkent,Chennai,Kolkata,Mumbai,New Delhi,Sri Jayawardenepura,Kathmandu,Almaty,Astana,Dhaka,Urumqi,Rangoon,Bangkok,Hanoi,Jakarta,Krasnoyarsk,Novosibirsk,Beijing,Chongqing,Hong Kong,Irkutsk,Kuala Lumpur,Perth,Singapore,Taipei,Ulaan Bataar,Osaka,Sapporo,Seoul,Tokyo,Yakutsk,Adelaide,Darwin,Brisbane,Canberra,Guam,Hobart,Melbourne,Port Moresby,Sydney,Vladivostok,Magadan,New Caledonia,Solomon Is.,Auckland,Fiji,Kamchatka,Marshall Is.,Wellington,Nuku'alofa,Samoa,Tokelau Is."

  def teardown
    Account.unstub(:current)
    super
  end

  def test_valid
    Account.stubs(:current).returns(Account.new)
    agent_item = Agent.new
    agent_item.user = User.new
    agent = ApiProfileValidation.new({ time_zone: 'Central Time (US & Canada)',
                                      language: 'hu',
                                      signature: Faker::Lorem.paragraph,
                                      shortcuts_enabled: true,
                                      job_title: Faker::Name.name },
                                      agent_item)
    assert agent.valid?
  end

  def test_invalid_data
    Account.stubs(:current).returns(Account.new)
    agent_item = Agent.new
    agent_item.user = User.new
    agent = ApiProfileValidation.new({ time_zone: 'dummy Time (US & Canada)',
                                       language: 'dummy',
                                       signature: 123,
                                       job_title: 234,
                                       shortcuts_enabled: 'yes'},
                                       agent_item)
    refute agent.valid?
    errors = agent.errors.sort.to_h
    error_options = agent.error_options.sort.to_h
    assert_equal({ job_title: :datatype_mismatch, language: :not_included, signature: :datatype_mismatch, time_zone: :not_included, shortcuts_enabled: :datatype_mismatch }, errors)
    assert_equal({ job_title: { expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer },
                   language: { list: I18n.available_locales.map(&:to_s).join(',') },
                   signature: { expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer },
                   time_zone: { list: TIME_ZONE_LIST },
                   shortcuts_enabled: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String } },
                   error_options)
  end

  def test_profile_with_blank_mandatory_fields
    Account.stubs(:current).returns(Account.new)
    agent_item = Agent.new
    agent_item.user = User.new
    agent = ApiProfileValidation.new({ time_zone: '', language: ''}, agent_item)
    refute agent.valid?
    errors = agent.errors.sort.to_h
    error_options = agent.error_options.sort.to_h
    assert_equal({ language: :not_included, time_zone: :not_included }, errors)
    assert_equal({ language: { list: I18n.available_locales.map(&:to_s).join(',') },
                   time_zone: { list: TIME_ZONE_LIST } },
                   error_options)
  end

  def test_profile_with_length_valid
    Account.stubs(:current).returns(Account.new)
    agent_item = Agent.new
    agent_item.user = User.new
    agent = ApiProfileValidation.new({ job_title: Faker::Lorem.characters(300) }, agent_item)
    refute agent.valid?
    errors = agent.errors.sort.to_h
    error_options = agent.error_options.sort.to_h
    assert_equal({ job_title: :too_long, time_zone: :not_included }, errors)
    assert_equal({ job_title: { min_count: 0, max_count: 255, current_count: 300, element_type: :characters, elements: 'job_title' },
                   language: {},
                   time_zone: { list: TIME_ZONE_LIST } },
                   error_options)
  end
end