require_relative '../unit_test_helper'
require "#{Rails.root}/test/api/helpers/default_field_validator_test_helper.rb"
require "#{Rails.root}/test/api/helpers/test_case_methods.rb"

class DefaultFieldValidatorTest < ActionView::TestCase
  class TestValidation < MockTestValidation
    include ActiveModel::Validations
    attr_accessor :source, :status, :priority, :type, :group_id, :responder_id, :product_id, :subject, :description, :description_html,
                  :email, :phone, :mobile, :client_manager, :company_id, :tags, :address, :job_title, :twitter_id, :language, :time_zone,
                  :domains, :note, :allow_string_param, :attribute1

    validates :source, :status, :priority, :type, :group_id, :responder_id, :product_id, :subject, :description,
              :email, :phone, :mobile, :client_manager, :company_id, :tags, :address, :job_title, :twitter_id, :language, :time_zone,
              :domains, :note, default_field: {
                required_fields: DefaultFieldValidatorTestHelper.required_fields,
                field_validations: DefaultFieldValidatorTestHelper.default_field_validations
              }

    validates :attribute1, default_field: {
      required_fields: [],
      field_validations: {}
    }

    def initialize(params = {}, allow_string_param = false)
      super
      params.each do |key, value|
        send("#{key}=", value) if respond_to?("#{key}=")
      end
      @allow_string_param = allow_string_param
    end
  end

  class InvalidValidatorTest
    include ActiveModel::Validations

    attr_accessor :error_options, :allow_string_param, :attribute1

    def initialize(params = {}, allow_string_param = false)
      super
      params.each do |key, value|
        send("#{key}=", value) if respond_to?("#{key}=")
      end
      @allow_string_param = allow_string_param
    end

    validates :attribute1, default_field: {
      required_fields: [DefaultFieldValidatorTestHelper.new(name: 'attribute1')],
      field_validations: { attribute1: { data_time: { allow_nil: false } } }
    }
  end

  def test_values_valid
    params = { source: '2', status: '2', priority: '1', type: 'Lead', group_id: 1, responder_id: 1, product_id: 1, subject: Faker::Name.name, description: Faker::Lorem.paragraph,
               email: Faker::Internet.email, phone: '123455', mobile: '12344', client_manager: true, company_id: 1, tags: [Faker::Name.name, Faker::Name.name], address: Faker::Lorem.characters(200),
               job_title: Faker::Name.name, twitter_id: Faker::Name.name, language: 'en', time_zone: 'Chennai', domains: [Faker::Internet.domain_word], note: Faker::Name.name }
    test = TestValidation.new(params, true)
    assert test.valid?
    assert test.errors.empty?
  end

  def test_value_invalid
    params = { source: '23', status: '223', priority: '21', type: 'LeadTest', group_id: '1', responder_id: '1', product_id: '1', subject: Faker::Lorem.characters(10) + white_space, description: 123,
               email: 'Faker::Internet.email', phone: '123455' + white_space, mobile: '12344' + white_space, client_manager: '0', company_id: '1', tags: 'Faker::Name.name, Faker::Name.name', address: Faker::Lorem.characters(255) + white_space,
               job_title: Faker::Lorem.characters(10) + white_space, twitter_id: Faker::Lorem.characters(10) + white_space,  language: 'enTest', time_zone: 'chennai-perungudi', domains: 'Faker::Internet.domain_word', note: 1234 }
    test = TestValidation.new(params)
    refute test.valid?
    errors = test.errors.to_h.sort
    error_options = test.error_options.to_h.sort
    assert_equal({
      source: :not_included, status: :not_included, priority: :not_included, type: :not_included, group_id: :datatype_mismatch,
      responder_id: :datatype_mismatch, product_id: :datatype_mismatch, email: :invalid_format,
      client_manager: :datatype_mismatch, tags: :datatype_mismatch, language: :not_included, time_zone: :not_included, domains: :datatype_mismatch,
      subject: :too_long, description: :datatype_mismatch,
      job_title: :too_long, twitter_id: :too_long,
      phone: :too_long, mobile: :too_long,
      address: :too_long, note: :datatype_mismatch
    }.sort,
                 errors
                )
    assert_equal({ address: { max_count: 255, current_count: 555, element_type: :characters, min_count: 0, elements: 'addres' }, client_manager: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String },
                   company_id: {}, description: { expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer }, domains: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: String },
                   email: { accepted: :'valid email address' }, group_id: { expected_data_type: :'Positive Integer', prepend_msg: :input_received, given_data_type: String, code: :datatype_mismatch },
                   job_title: { max_count: 255, current_count: 310, element_type: :characters, min_count: 0, elements: 'job_title' }, language: { list: I18n.available_locales.map(&:to_s).join(',') },
                   mobile: { max_count: 255, current_count: 305, element_type: :characters, min_count: 0, elements: 'mobile' }, note: { expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer }, phone: { max_count: 255, current_count: 306, element_type: :characters, min_count: 0, elements: 'phone' },
                   priority: { list: '1,2,3,4' }, product_id: { expected_data_type: :'Positive Integer', prepend_msg: :input_received, given_data_type: String, code: :datatype_mismatch }, responder_id: { expected_data_type: :'Positive Integer', prepend_msg: :input_received, given_data_type: String, code: :datatype_mismatch },
                   source: { list: '1,2,3,5,6,7,8,9,11' }, status: { list: '2,3,4,5' }, subject: { max_count: 255, current_count: 310, element_type: :characters, min_count: 0, elements: 'subject' }, tags: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: String },
                   time_zone: { list: "American Samoa,International Date Line West,Midway Island,Hawaii,Alaska,Pacific Time (US & Canada),Tijuana,Arizona,Chihuahua,Mazatlan,Mountain Time (US & Canada),Central America,Central Time (US & Canada),Guadalajara,Mexico City,Monterrey,Saskatchewan,Bogota,Eastern Time (US & Canada),Indiana (East),Lima,Quito,Atlantic Time (Canada),Caracas,Georgetown,La Paz,Santiago,Newfoundland,Brasilia,Buenos Aires,Greenland,Mid-Atlantic,Azores,Cape Verde Is.,Casablanca,Dublin,Edinburgh,Lisbon,London,Monrovia,UTC,Amsterdam,Belgrade,Berlin,Bern,Bratislava,Brussels,Budapest,Copenhagen,Ljubljana,Madrid,Paris,Prague,Rome,Sarajevo,Skopje,Stockholm,Vienna,Warsaw,West Central Africa,Zagreb,Athens,Bucharest,Cairo,Harare,Helsinki,Istanbul,Jerusalem,Kyiv,Pretoria,Riga,Sofia,Tallinn,Vilnius,Baghdad,Kuwait,Minsk,Moscow,Nairobi,Riyadh,St. Petersburg,Volgograd,Tehran,Abu Dhabi,Baku,Muscat,Tbilisi,Yerevan,Kabul,Ekaterinburg,Islamabad,Karachi,Tashkent,Chennai,Kolkata,Mumbai,New Delhi,Sri Jayawardenepura,Kathmandu,Almaty,Astana,Dhaka,Urumqi,Rangoon,Bangkok,Hanoi,Jakarta,Krasnoyarsk,Novosibirsk,Beijing,Chongqing,Hong Kong,Irkutsk,Kuala Lumpur,Perth,Singapore,Taipei,Ulaan Bataar,Osaka,Sapporo,Seoul,Tokyo,Yakutsk,Adelaide,Darwin,Brisbane,Canberra,Guam,Hobart,Melbourne,Port Moresby,Sydney,Vladivostok,Magadan,New Caledonia,Solomon Is.,Auckland,Fiji,Kamchatka,Marshall Is.,Wellington,Nuku'alofa,Samoa,Tokelau Is." }, twitter_id: { max_count: 255, current_count: 310, element_type: :characters, min_count: 0, elements: 'twitter_id' }, type: { list: 'Lead,Question,Problem,Maintenance,Breakage' } }.sort,
                 error_options
                )
  end

  def test_required_value
    test = TestValidation.new({})
    refute test.valid?
    errors = test.errors.to_h.sort
    error_options = test.error_options.to_h.sort
    assert_equal({
      source: :not_included, company_id: :missing_field, status: :not_included, priority: :not_included, type: :not_included, group_id: :datatype_mismatch,
      responder_id: :datatype_mismatch, product_id: :datatype_mismatch, email: :missing_field,
      client_manager: :datatype_mismatch, tags: :datatype_mismatch, language: :not_included, time_zone: :not_included, domains: :datatype_mismatch,
      subject: :missing_field, job_title: :datatype_mismatch, description: :datatype_mismatch, twitter_id: :missing_field, phone: :missing_field, mobile: :missing_field, address: :missing_field, note: :datatype_mismatch
    }.sort,
                 errors
                )
    assert_equal({
      source: { list: '1,2,3,5,6,7,8,9,11', code: :missing_field }, status: { list: '2,3,4,5', code: :missing_field }, priority: { list: '1,2,3,4', code: :missing_field }, type: { list: 'Lead,Question,Problem,Maintenance,Breakage', code: :missing_field }, group_id: { expected_data_type: :'Positive Integer', code: :missing_field },
      responder_id: {  expected_data_type: :'Positive Integer', code: :missing_field }, product_id: {  expected_data_type: :'Positive Integer', code: :missing_field }, client_manager: {  expected_data_type: 'Boolean', code: :missing_field },
      description: {  expected_data_type: String, code: :missing_field }, note: {  expected_data_type: String, code: :missing_field }, job_title: {  expected_data_type: String, code: :missing_field },
      tags: {  expected_data_type: Array, code: :missing_field }, language: { list: I18n.available_locales.map(&:to_s).join(','), code: :missing_field }, time_zone: { list: ActiveSupport::TimeZone.all.map(&:name).join(','), code: :missing_field }, domains: {  expected_data_type: Array, code: :missing_field },
      address: { code: :missing_field }, company_id: { code: :missing_field }, email: { code: :missing_field }, mobile: { code: :missing_field }, phone: { code: :missing_field }, subject: { code: :missing_field }, twitter_id: { code: :missing_field }
    }.sort,
                 error_options
                )
  end

  def test_array_length_validator
    params = {  source: '2', status: '2', priority: '1', type: 'Lead', group_id: 1, responder_id: 1, product_id: 1, subject: Faker::Name.name, description: Faker::Lorem.paragraph,
                email: Faker::Internet.email, phone: '123455', mobile: '12344', client_manager: true, company_id: 1, tags: ["#{Faker::Lorem.characters(17)}#{ ' ' * 20}#{Faker::Lorem.characters(17)}"], address: Faker::Lorem.name,
                job_title: Faker::Name.name, twitter_id: Faker::Name.name, language: 'en', time_zone: 'Chennai', domains: [Faker::Internet.domain_word], note: Faker::Name.name }
    test = TestValidation.new(params, true)
    refute test.valid?
    errors = test.errors.to_h.sort
    assert_equal({ tags: :array_too_long }.sort, errors)
    assert_equal({ source: {}, status: {}, priority: {}, type: {}, group_id: {}, responder_id: {}, product_id: {}, subject: {}, description: {}, email: {}, phone: {}, mobile: {}, client_manager: {}, company_id: {}, tags: { min_count: 0,max_count: 32, current_count: 54, element_type: :characters, elements: 'tag' }, address: {}, job_title: {}, twitter_id: {}, language: {}, time_zone: {}, domains: {}, note: {} }, test.error_options)
  end

  def test_string_rejection_validator
    tags = [Faker::Lorem.characters(10) + ', Faker', Faker::Lorem.characters(10)]
    domains = [Faker::Internet.domain_word + ', Faker']
    params = {  source: '2', status: '2', priority: '1', type: 'Lead', group_id: 1, responder_id: 1, product_id: 1, subject: Faker::Name.name, description: Faker::Lorem.paragraph,
                email: Faker::Internet.email, phone: '123455', mobile: '12344', client_manager: true, company_id: 1, tags: tags, address: Faker::Lorem.characters(200),
                job_title: Faker::Name.name, twitter_id: Faker::Name.name, language: 'en', time_zone: 'Chennai', domains: domains, note: Faker::Name.name }
    test = TestValidation.new(params, true)
    refute test.valid?
    errors = test.errors.to_h.sort
    error_options = test.error_options.to_h.sort
    assert_equal({ tags: :special_chars_present, domains: :special_chars_present }.sort, errors)
    assert_equal({ tags: { chars: ',' }, domains: { chars: ',' }, address: {}, client_manager: {}, company_id: {}, description: {}, email: {}, group_id: {}, job_title: {}, language: {}, mobile: {}, note: {}, phone: {}, priority: {}, product_id: {}, responder_id: {}, source: {}, status: {}, subject: {}, time_zone: {}, twitter_id: {}, type: {} }.sort, error_options)
  end

  def test_validator_chaining_for_email
    params = { source: '2', status: '2', priority: '1', type: 'Lead', group_id: 1, responder_id: 1, product_id: 1, 
               subject: Faker::Name.name, description: Faker::Lorem.paragraph,
               email: "#{Faker::Lorem.characters(300)}@#{Faker::Lorem.characters(20)}.com", phone: '123455', mobile: '12344', 
               client_manager: true, company_id: 1, tags: [Faker::Name.name, Faker::Name.name], 
               address: Faker::Lorem.characters(200),
               job_title: Faker::Name.name, twitter_id: Faker::Name.name, language: 'en', time_zone: 'Chennai', domains: [Faker::Internet.domain_word], note: Faker::Name.name }
    test = TestValidation.new(params, true)
    refute test.valid?
    errors = test.errors.to_h.sort
    assert_equal({ email: :too_long }.sort, errors)
    assert_equal({ source: {}, status: {}, priority: {}, type: {}, group_id: {}, responder_id: {}, product_id: {}, subject: {}, description: {}, email: { min_count: 0, max_count: 255, current_count: 325, element_type: :characters, elements: 'email' }, phone: {}, mobile: {}, client_manager: {}, company_id: {}, tags: {}, address: {}, job_title: {}, twitter_id: {}, language: {}, time_zone: {}, domains: {}, note: {} }, test.error_options)
  end

  def test_attribute_with_no_validation
    params = { attribute1: 'test', source: '2', status: '2', priority: '1', type: 'Lead', group_id: 1, responder_id: 1, product_id: 1, subject: Faker::Name.name, description: Faker::Lorem.paragraph,
               email: Faker::Internet.email, phone: '123455', mobile: '12344', client_manager: true, company_id: 1, tags: [Faker::Name.name, Faker::Name.name], address: Faker::Lorem.characters(200),
               job_title: Faker::Name.name, twitter_id: Faker::Name.name, language: 'en', time_zone: 'Chennai', domains: [Faker::Internet.domain_word], note: Faker::Name.name }
    test = TestValidation.new(params, true)
    assert test.valid?
    assert test.errors.empty?
  end

  def test_invalid_validator
    assert_raises(ArgumentError) do
      test = InvalidValidatorTest.new({ attribute1: 'Test' }, true)
      assert test.valid?
    end
  end
end
