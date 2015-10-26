require_relative '../unit_test_helper'
require "#{Rails.root}/test/api/helpers/default_field_validator_helper.rb"
require "#{Rails.root}/test/api/helpers/test_case_methods.rb"

class DefaultFieldValidatorTest < ActionView::TestCase
  class TestValidation
    include ActiveModel::Validations
    attr_accessor :source, :status, :priority, :type, :group_id, :responder_id, :product_id, :subject, :description, :description_html,
                  :email, :phone, :mobile, :client_manager, :company_id, :tags, :address, :job_title, :twitter_id, :language, :time_zone,
                  :domains, :note, :allow_string_param, :error_options, :attribute1

    validates :source, :status, :priority, :type, :group_id, :responder_id, :product_id, :subject, :description,
              :email, :phone, :mobile, :client_manager, :company_id, :tags, :address, :job_title, :twitter_id, :language, :time_zone,
              :domains, :note, default_field: {
                required_fields: Helpers::DefaultFieldValidatorHelper.required_fields,
                field_validations: Helpers::DefaultFieldValidatorHelper.default_field_validations
              }
    validates :attribute1, default_field: {
      required_fields: [],
      field_validations: {}
    }

    def initialize(params = {}, allow_string_param = false)
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
      params.each do |key, value|
        send("#{key}=", value) if respond_to?("#{key}=")
      end
      @allow_string_param = allow_string_param
    end

    validates :attribute1, default_field: {
      required_fields: [Helpers::DefaultFieldValidatorHelper.new(name: 'attribute1')],
      field_validations: { attribute1: { data_time: { allow_nil: false } } }
    }
  end

  def test_values_valid
    params = { source: '2', status: '2', priority: '1', type: 'Lead', group_id: 1, responder_id: 1, product_id: 1, subject: Faker::Name.name, description: Faker::Lorem.paragraph,
               email: Faker::Internet.email, phone: '123455', mobile: '12344', client_manager: true, company_id: 1, tags: [Faker::Name.name, Faker::Name.name], address: Faker::Lorem.paragraph,
               job_title: Faker::Name.name, twitter_id: Faker::Name.name, language: 'en', time_zone: 'Chennai', domains: [Faker::Internet.domain_word], note: Faker::Name.name }
    test = TestValidation.new(params, true)
    assert test.valid?
    assert test.errors.empty?
  end

  def test_value_invalid
    params = { source: '23', status: '223', priority: '21', type: 'LeadTest', group_id: '1', responder_id: '1', product_id: '1', subject: Faker::Name.name + white_space, description: 123,
               email: 'Faker::Internet.email', phone: '123455' + white_space, mobile: '12344' + white_space, client_manager: '0', company_id: '1', tags: 'Faker::Name.name, Faker::Name.name', address: Faker::Lorem.paragraph + white_space,
               job_title: Faker::Name.name + white_space, twitter_id: Faker::Name.name + white_space,  language: 'enTest', time_zone: 'chennai-perungudi', domains: 'Faker::Internet.domain_word', note: 1234 }
    test = TestValidation.new(params)
    refute test.valid?
    errors = test.errors.to_h.sort
    error_options = test.error_options.to_h.sort
    assert_equal({
      source: 'not_included', status: 'not_included', priority: 'not_included', type: 'not_included', group_id: 'data_type_mismatch',
      responder_id: 'data_type_mismatch', product_id: 'data_type_mismatch', email: 'not_a_valid_email',
      client_manager: 'data_type_mismatch', tags: 'data_type_mismatch', language: 'not_included', time_zone: 'not_included', domains: 'data_type_mismatch',
      subject: 'is too long (maximum is 255 characters)', description: 'data_type_mismatch',
      job_title: 'is too long (maximum is 255 characters)', twitter_id: 'is too long (maximum is 255 characters)',
      phone: 'is too long (maximum is 255 characters)', mobile: 'is too long (maximum is 255 characters)',
      address: 'is too long (maximum is 255 characters)', note: 'data_type_mismatch'
    }.sort,
                 errors
                )
    assert_equal({
      source: { list: '1,2,3,7,8,9' }, status: { list: '2,3,4,5' }, priority: { list: '1,2,3,4' }, type: { list: 'Lead,Question,Problem,Maintenance,Breakage' }, group_id: { data_type: 'Positive Integer' },
      responder_id: { data_type: 'Positive Integer' }, product_id: { data_type: 'Positive Integer' }, client_manager: { data_type: 'Boolean' },
      tags: { data_type: Array }, language: { list: I18n.available_locales.map(&:to_s).join(',') }, time_zone: { list: ActiveSupport::TimeZone.all.map(&:name).join(',') },
      domains: { data_type: Array }, description: { data_type: String }, note: { data_type: String }
    }.sort,
                 error_options
                )
  end

  def test_required_value
    test = TestValidation.new({})
    refute test.valid?
    errors = test.errors.to_h.sort
    error_options = test.error_options.to_h.sort
    assert_equal({
      source: 'required_and_inclusion', company_id: 'missing', status: 'required_and_inclusion', priority: 'required_and_inclusion', type: 'required_and_inclusion', group_id: 'required_and_data_type_mismatch',
      responder_id: 'required_and_data_type_mismatch', product_id: 'required_and_data_type_mismatch', email: 'missing',
      client_manager: 'required_and_data_type_mismatch', tags: 'required_and_data_type_mismatch', language: 'required_and_inclusion', time_zone: 'required_and_inclusion', domains: 'required_and_data_type_mismatch',
      subject: 'missing', job_title: 'required_and_data_type_mismatch', description: 'required_and_data_type_mismatch', twitter_id: 'missing', phone: 'missing', mobile: 'missing', address: 'missing', note: 'required_and_data_type_mismatch'
    }.sort,
                 errors
                )
    assert_equal({
      source: { list: '1,2,3,7,8,9' }, status: { list: '2,3,4,5' }, priority: { list: '1,2,3,4' }, type: { list: 'Lead,Question,Problem,Maintenance,Breakage' }, group_id: { data_type: 'Positive Integer' },
      responder_id: { data_type: 'Positive Integer' }, product_id: { data_type: 'Positive Integer' }, client_manager: { data_type: 'Boolean' },
      description: { data_type: String }, note: { data_type: String }, job_title: { data_type: String },
      tags: { data_type: Array }, language: { list: I18n.available_locales.map(&:to_s).join(',') }, time_zone: { list: ActiveSupport::TimeZone.all.map(&:name).join(',') }, domains: { data_type: Array }
    }.sort,
                 error_options
                )
  end

  def test_array_length_validator
    params = {  source: '2', status: '2', priority: '1', type: 'Lead', group_id: 1, responder_id: 1, product_id: 1, subject: Faker::Name.name, description: Faker::Lorem.paragraph,
                email: Faker::Internet.email, phone: '123455', mobile: '12344', client_manager: true, company_id: 1, tags: [Faker::Name.name + white_space, Faker::Name.name + white_space], address: Faker::Lorem.paragraph,
                job_title: Faker::Name.name, twitter_id: Faker::Name.name, language: 'en', time_zone: 'Chennai', domains: [Faker::Internet.domain_word], note: Faker::Name.name }
    test = TestValidation.new(params, true)
    refute test.valid?
    errors = test.errors.to_h.sort
    assert_equal({ tags: 'is too long (maximum is 255 characters)' }.sort, errors)
  end

  def test_string_rejection_validator
    params = {  source: '2', status: '2', priority: '1', type: 'Lead', group_id: 1, responder_id: 1, product_id: 1, subject: Faker::Name.name, description: Faker::Lorem.paragraph,
                email: Faker::Internet.email, phone: '123455', mobile: '12344', client_manager: true, company_id: 1, tags: [Faker::Name.name + ', Faker', Faker::Name.name], address: Faker::Lorem.paragraph,
                job_title: Faker::Name.name, twitter_id: Faker::Name.name, language: 'en', time_zone: 'Chennai', domains: [Faker::Internet.domain_word + ', Faker'], note: Faker::Name.name }
    test = TestValidation.new(params, true)
    refute test.valid?
    errors = test.errors.to_h.sort
    error_options = test.error_options.to_h.sort
    assert_equal({ tags: 'special_chars_present', domains: 'special_chars_present' }.sort, errors)
    assert_equal({ tags: { chars: ',' }, domains: { chars: ',' } }.sort, error_options)
  end

  def test_validator_chaining_for_email
    params = { source: '2', status: '2', priority: '1', type: 'Lead', group_id: 1, responder_id: 1, product_id: 1, subject: Faker::Name.name, description: Faker::Lorem.paragraph,
               email: "#{Faker::Lorem.characters(300)}@#{Faker::Lorem.characters(20)}.com", phone: '123455', mobile: '12344', client_manager: true, company_id: 1, tags: [Faker::Name.name, Faker::Name.name], address: Faker::Lorem.paragraph,
               job_title: Faker::Name.name, twitter_id: Faker::Name.name, language: 'en', time_zone: 'Chennai', domains: [Faker::Internet.domain_word], note: Faker::Name.name }
    test = TestValidation.new(params, true)
    refute test.valid?
    errors = test.errors.to_h.sort
    assert_equal({ email: 'is too long (maximum is 255 characters)' }.sort, errors)
  end

  def test_attribute_with_no_validation
    params = { attribute1: 'test', source: '2', status: '2', priority: '1', type: 'Lead', group_id: 1, responder_id: 1, product_id: 1, subject: Faker::Name.name, description: Faker::Lorem.paragraph,
               email: Faker::Internet.email, phone: '123455', mobile: '12344', client_manager: true, company_id: 1, tags: [Faker::Name.name, Faker::Name.name], address: Faker::Lorem.paragraph,
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
