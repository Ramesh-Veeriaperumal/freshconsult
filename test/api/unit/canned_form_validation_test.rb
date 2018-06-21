require_relative '../unit_test_helper'

class CannedFormValidationTest < ActionView::TestCase

  def test_invalid
    Account.stubs(:current).returns(Account.new)
    params = {
      name: 1234,
      welcome_text: 123, thankyou_text: 123,
      version: 'test', fields: 'test'
    }
    canned_form_validation = CannedFormValidation.new(params)
    refute canned_form_validation.valid?
    error_options = canned_form_validation.error_options.to_h
    assert_equal({
      name: { expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer },
      welcome_text: { expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer },
      thankyou_text: { expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer },
      fields: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: String }
    }, error_options)
    Account.unstub(:current)
  end

  def test_minimum_field_length
    Account.stubs(:current).returns(Account.new)
    fields = []
    fields << field_payload_1.merge('deleted' => true)
    params = {
      fields: fields
    }
    canned_form_validation = CannedFormValidation.new(params)
    refute canned_form_validation.valid?
    error_options = canned_form_validation.error_options.to_h
    assert_equal({
      fields: { :element_type => :fields, :min_count => CannedFormConstants::MIN_FIELD_LIMIT, :current_count => fields.select{ |x| x['deleted'] != true }.length, :max_count => CannedFormConstants::MAX_FIELD_LIMIT }
    }, error_options)
    Account.unstub(:current)
  end

  def test_minimum_choice_length
    Account.stubs(:current).returns(Account.new)
    choices = []
    2.times do 
      choices << choice_payload.merge('_destroy' => true)
    end
    fields = []
    fields << field_payload_2.merge('choices' => choices)
    params = {
      fields: fields
    }
    canned_form_validation = CannedFormValidation.new(params)
    refute canned_form_validation.valid?
    error_options = canned_form_validation.error_options.to_h
    assert_equal({
      fields: { :element_type => :choices, :min_count => CannedFormConstants::MIN_CHOICE_LIMIT, :current_count => 0, :max_count => CannedFormConstants::MAX_CHOICE_LIMIT }
    }, error_options)
    Account.unstub(:current)
  end

  def test_exceed_form_limit
    Account.stubs(:current).returns(Account.new)
    Account.current.stubs(:canned_forms).returns(Admin::CannedForm)
    Account.current.canned_forms.stubs(:active_forms).returns(Array.new(20, Admin::CannedForm))
    params = {
      name: Faker::Name.name,
      welcome_text: Faker::Lorem.characters(100), thankyou_text: Faker::Lorem.characters(100),
      version: 1, fields: []
    }
    canned_form_validation = CannedFormValidation.new(params)
    refute canned_form_validation.valid?(:create)
    Account.current.canned_forms.unstub(:active_forms)
    Account.current.unstub(:canned_forms)
    Account.unstub(:current)
  end

  def test_form_limit_with_constant
    Account.stubs(:current).returns(Account.new)
    Account.current.stubs(:canned_forms).returns(Admin::CannedForm)
    Account.current.canned_forms.stubs(:active_forms).returns(Array.new(20, Admin::CannedForm))
    params = {
      name: Faker::Name.name,
      welcome_text: Faker::Lorem.characters(100), thankyou_text: Faker::Lorem.characters(100),
      version: 1, fields: []
    }
    canned_form_validation = CannedFormValidation.new(params)
    refute canned_form_validation.valid?(:create)
    Account.current.canned_forms.unstub(:active_forms)
    Account.current.unstub(:canned_forms)
    Account.unstub(:current)
  end

  def test_form_limit_with_redis
    Account.stubs(:current).returns(Account.new)
    Account.current.stubs(:canned_forms).returns(Admin::CannedForm)
    Account.current.canned_forms.stubs(:active_forms).returns(Array.new(6, Admin::CannedForm))
    params = {
      name: Faker::Name.name,
      welcome_text: Faker::Lorem.characters(100), thankyou_text: Faker::Lorem.characters(100),
      version: 1, fields: []
    }
    canned_form_validation = CannedFormValidation.new(params)
    canned_form_validation.stubs(:get_others_redis_key).returns("6")
    refute canned_form_validation.valid?(:create)
    canned_form_validation.unstub(:get_others_redis_key)
    Account.current.canned_forms.unstub(:active_forms)
    Account.current.unstub(:canned_forms)
    Account.unstub(:current)
  end

  def test_valid
    Account.stubs(:current).returns(Account.new)
    fields = []
    fields << field_payload_1
    choices = []
    2.times do 
      choices << choice_payload
    end
    fields << field_payload_2.merge('choices' => choices)
    params = {
      name: Faker::Name.name,
      welcome_text: Faker::Lorem.characters(100), thankyou_text: Faker::Lorem.characters(100),
      version: 1, fields: fields
    }
    canned_form_validation = CannedFormValidation.new(params)
    assert canned_form_validation.valid?
    Account.unstub(:current)
  end

  private

    def field_payload_1
      {
        "name" => "text_#{Faker::Number.number(10)}",
        "label" => Faker::Lorem.characters(10),
        "type" => 1,
        "position" => 1,
        "placeholder" => Faker::Lorem.characters(10),
        "deleted" => false,
        "custom" => true,
        "choices" => [
        ],
        "id" => nil
      }
    end

    def field_payload_2
      {
        "name" => "dropdown_#{Faker::Number.number(10)}",
        "label" => Faker::Lorem.characters(10),
        "type" => 2,
        "position" => 2,
        "placeholder" => nil,
        "deleted" => false,
        "custom" => true,
        "choices" => [
        ],
        "id" => nil
      }
    end

    def choice_payload
      {
        "value" => Faker::Lorem.characters(10),
        "type" => nil,
        "position" => 1,
        "custom" => true,
        "_destroy" => false,
        "id" => Faker::Number.number(10)
      }
    end
end
