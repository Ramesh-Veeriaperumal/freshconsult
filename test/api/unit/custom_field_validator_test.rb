require_relative '../unit_test_helper'
require "#{Rails.root}/test/api/helpers/custom_field_validator_test_helper.rb"

class CustomFieldValidatorTest < ActionView::TestCase
  class RequiredTestValidation
    include ActiveModel::Validations

    attr_accessor :attribute3, :attribute4, :error_options, :closed_status, :allow_string_param
    validates :attribute3, :attribute4, custom_field:  { attribute3: {
      validatable_custom_fields: proc { CustomFieldValidatorTestHelper.required_choices_validatable_custom_fields },
      drop_down_choices: proc { CustomFieldValidatorTestHelper.dropdown_choices_by_field_name },
      nested_field_choices: proc { CustomFieldValidatorTestHelper.nested_fields_choices_by_name },
      required_based_on_status: proc { |x| x.required_for_closure? },
      required_attribute: :required
    },
                                                         attribute4: {
                                                           validatable_custom_fields: proc { CustomFieldValidatorTestHelper.required_data_type_validatable_custom_fields },
                                                           required_based_on_status: proc { |x| x.required_for_closure? },
                                                           required_attribute: :required
                                                         }
                            }

    def initialize(params = {})
      params.each { |key, value| instance_variable_set("@#{key}", value) }
    end

    def required_for_closure?
      closed_status == true
    end
  end

  class RequiredClosureTestValidation
    include ActiveModel::Validations

    attr_accessor :attribute5, :attribute6, :error_options, :closed_status, :allow_string_param
    validates :attribute5, :attribute6, custom_field:  { attribute5: {
      validatable_custom_fields: proc { CustomFieldValidatorTestHelper.required_closure_choices_validatable_custom_fields },
      drop_down_choices: proc { CustomFieldValidatorTestHelper.dropdown_choices_by_field_name },
      nested_field_choices: proc { CustomFieldValidatorTestHelper.nested_fields_choices_by_name },
      required_based_on_status: proc { |x| x.required_for_closure? },
      required_attribute: :required
    },
                                                         attribute6: {
                                                           validatable_custom_fields: proc { CustomFieldValidatorTestHelper.required_closure_data_type_validatable_custom_fields },
                                                           required_based_on_status: proc { |x| x.required_for_closure? },
                                                           required_attribute: :required
                                                         }
                            }

    def initialize(params = {})
      params.each { |key, value| instance_variable_set("@#{key}", value) }
    end

    def required_for_closure?
      closed_status == true
    end
  end

  class TestValidation
    include ActiveModel::Validations

    attr_accessor :attribute1, :attribute2, :error_options, :closed_status, :allow_string_param

    validates :attribute1, :attribute2, data_type: { rules: Hash, allow_nil: true }, custom_field: { attribute1: {
      validatable_custom_fields: proc { CustomFieldValidatorTestHelper.choices_validatable_custom_fields },
      drop_down_choices: proc { CustomFieldValidatorTestHelper.dropdown_choices_by_field_name },
      nested_field_choices: proc { CustomFieldValidatorTestHelper.nested_fields_choices_by_name },
      required_based_on_status: proc { |x| x.required_for_closure? },
      required_attribute: :required
    },
                                                                                                     attribute2: {
                                                                                                       validatable_custom_fields: proc { CustomFieldValidatorTestHelper.data_type_validatable_custom_fields },
                                                                                                       required_based_on_status: proc { |x| x.required_for_closure? },
                                                                                                       required_attribute: :required
                                                                                                     }
                            }

    def initialize(params = {})
      params.each { |key, value| instance_variable_set("@#{key}", value) }
    end

    def required_for_closure?
      closed_status == true
    end
  end

  class TestInvalidTypeValidation
    include ActiveModel::Validations

    attr_accessor :attribute1, :error_options, :closed_status, :allow_string_param

    validates :attribute1, custom_field: { attribute1: {
      validatable_custom_fields: [CustomFieldValidatorTestHelper.new(id: 14, account_id: 1, name: 'second_1', label: 'second', label_in_portal: 'second', description: nil, active: true, field_type: 'junk_field', position: 22, required: false, visible_in_portal: false, editable_in_portal: false, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 4, created_at: '2015-08-10 09:19:28', updated_at: '2015-08-10 14:56:52', field_options: nil, default: false, level: 2, parent_id: 13, prefered_ff_col: nil, import_id: nil)],
      required_based_on_status: proc { |x| x.required_for_closure? },
      required_attribute: :required
    }
                            }

    def initialize(params = {})
      params.each { |key, value| instance_variable_set("@#{key}", value) }
    end

    def required_for_closure?
      closed_status == true
    end
  end

  def test_choices_validatable_fields_valid
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'dropdown2_1' => 'first11' })
    assert test.valid?
    assert test.errors.empty?
  end

  def test_choices_validatable_fields_invalid
    test = TestValidation.new(attribute1: { 'country_1' => 'klk', 'dropdown2_1' => 'jkjk', 'dropdown3_1' => 'efgh' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ country_1: :not_included, dropdown2_1: :not_included, dropdown3_1: :not_included }.sort.to_h, errors.sort.to_h)
    assert_equal({ country_1: { list: 'Usa,india' }, dropdown2_1: { list: 'first11,second22,third33,four44' }, dropdown3_1: { list: 'first,second' } }.stringify_keys.sort.to_h, test.error_options.sort.to_h)
  end

  def test_format_validatable_fields_invalid
    test = TestValidation.new(attribute2: { 'single_1' => [1, 2], 'check1_1' => 'ds', 'check2_1' => 'sd', 'decimal1_1' => 'sds', 'phone' => 3.4, 'decimal2_1' => 'sd', 'number1_1' => 909.898, 'number2_1' => 'dd', 'multi_1' => 9.0, 'url1_1' => 'udp:/testurl', 'url2_1' => 'http:/testurl.123' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal(
      {
        check1_1: :data_type_mismatch, single_1: :data_type_mismatch, multi_1: :data_type_mismatch, phone: :data_type_mismatch, check2_1: :data_type_mismatch, decimal1_1: 'is not a number',
        decimal2_1: 'is not a number', number1_1: :data_type_mismatch,
        number2_1: :data_type_mismatch, url1_1: 'invalid_format', url2_1: 'invalid_format'
      }.sort.to_h,
      errors.sort.to_h)
    assert_equal({
      check1_1: { data_type: 'Boolean' },
      check2_1: { data_type: 'Boolean' },
      number2_1: { data_type: :Integer },
      number1_1: { data_type: :Integer },
      single_1: { data_type: String },
      multi_1: { data_type: String },
      phone: { data_type: String }
    }.stringify_keys.sort.to_h, test.error_options.sort.to_h)
  end

  def test_format_validatable_fields_valid
    test = TestValidation.new(attribute1: { 'single_1' => 'w', 'check1_1' => false, 'check2_1' => true, 'decimal1_1' => 898, 'decimal2_1' => 9090, 'number1_1' => 5656, 'number2_1' => -787, 'multi_1' => 'dff', 'url' => 'http://testurl.co.test' })
    assert test.valid?
    assert test.errors.empty?
  end

  def test_nested_fields_valid
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'california', 'city_1' => 'los angeles' })
    assert test.valid?
    assert test.errors.empty?
  end

  def test_nested_fields_invalid_first_field
    test = TestValidation.new(attribute1: { 'country_1' => 'jkjk', 'state_1' => 'ww', 'city_1' => 'los ww' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ country_1: :not_included }, errors)
    assert_equal({ country_1: { list: 'Usa,india' } }.stringify_keys, test.error_options)
  end

  def test_nested_fields_invalid_second_field
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'uiuiu', 'city_1' => 'ww angeles' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ state_1: :not_included }, errors)
    assert_equal({ state_1: { list: 'california' } }.stringify_keys, test.error_options)
  end

  def test_nested_fields_invalid_third_field
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'california', 'city_1' => 'ddd' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ city_1: :not_included }, errors)
    assert_equal({ city_1: { list: 'los angeles,san fransico,san diego' } }.stringify_keys, test.error_options)
  end

  def test_nested_fields_without_parent_field_second
    acc = Account.new
    acc.id = 1
    Account.stubs(:current).returns(acc)
    test = TestValidation.new(attribute1: { 'state_1' => 'california', 'city_1' => 'ddd' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ country_1: :conditional_not_blank }, errors)
    assert_equal({ country_1: { child: 'state' } }.stringify_keys, test.error_options)
  ensure
    Account.unstub(:current)
  end

  def test_nested_fields_without_parent_field_third
    acc = Account.new
    acc.id = 1
    Account.stubs(:current).returns(acc)
    test = TestValidation.new(attribute1: { 'city_1' => 'ddd' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ country_1: :conditional_not_blank, state_1: :conditional_not_blank }.sort.to_h, errors.sort.to_h)
    assert_equal({ country_1: { child: 'city' }, state_1: { child: 'city' } }.stringify_keys.sort.to_h, test.error_options.sort.to_h)
  ensure
    Account.unstub(:current)
  end

  def test_attribute_with_errors
    test = TestValidation.new(attribute1: 'Junk string 1', attribute2: 'junk string 2')
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ attribute1: :data_type_mismatch, attribute2: :data_type_mismatch }, errors)
    assert errors.count == 2
  end

  def test_nested_fields_without_required_fields
    test = RequiredTestValidation.new
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ country_1: :required_and_inclusion, first_1: :required_and_inclusion, check2_1: :required_boolean, dropdown2_1: :required_and_inclusion, dropdown1_1: :required_and_inclusion, check1_1: :required_boolean, decimal1_1: 'required_number', decimal2_1: 'required_number', number1_1: :required_integer, number2_1: :required_integer, single_1: :required_string, multi_1: :required_string, phone: :required_string, dropdown3_1: :required_and_inclusion, dropdown4_1: :required_and_inclusion, check2_1: :required_boolean, check3_1: :required_boolean, decimal3_1: 'required_number', decimal4_1: 'required_number', multi2_1: :required_string, multi3_1: :required_string, number3_1: :required_integer, number4_1: :required_integer, phone_1: :required_string, phone2_1: :required_string, single2_1: :required_string, single3_1: :required_string, url1_1: 'required_format', url2_1: 'required_format', date_1: :required_date }.sort.to_h, errors.sort.to_h)
    assert_equal({ country_1: { list: 'Usa,india' }, first_1: { list: 'category 1,category 2' },
                   dropdown2_1: { list: 'first11,second22,third33,four44' }, dropdown3_1: { list: 'first,second' }, check2_1: { data_type: 'Boolean' }, check3_1: { data_type: 'Boolean' },
                   dropdown1_1: { list: '1st,2nd' }, dropdown4_1: { list: 'third,fourth' }, check1_1: { data_type: 'Boolean' },
                   number1_1: { data_type: :Integer }, number2_1: { data_type: :Integer }, number3_1: { data_type: :Integer },
                   number4_1: { data_type: :Integer }, single_1: { data_type: String }, single2_1: { data_type: String }, single3_1: { data_type: String },
                   multi_1: { data_type: String }, multi2_1: { data_type: String }, multi3_1: { data_type: String }, phone: { data_type: String },
                   phone_1: { data_type: String }, phone2_1: { data_type: String },
                   check2_1: { data_type: 'Boolean' } }.stringify_keys.sort.to_h, test.error_options.sort.to_h)
  end

  def test_nested_fields_without_required_closure_fields
    test = RequiredClosureTestValidation.new(closed_status: true)
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ country_1: :required_and_inclusion, first_1: :required_and_inclusion, check2_1: :required_boolean, dropdown2_1: :required_and_inclusion, dropdown1_1: :required_and_inclusion, check1_1: :required_boolean, decimal1_1: 'required_number', decimal2_1: 'required_number', number1_1: :required_integer, number2_1: :required_integer, single_1: :required_string, multi_1: :required_string, phone: :required_string, dropdown3_1: :required_and_inclusion, dropdown4_1: :required_and_inclusion, check2_1: :required_boolean, check3_1: :required_boolean, decimal3_1: 'required_number', decimal4_1: 'required_number', multi2_1: :required_string, multi3_1: :required_string, number3_1: :required_integer, number4_1: :required_integer, phone_1: :required_string, phone2_1: :required_string, single2_1: :required_string, single3_1: :required_string, url1_1: 'required_format', url2_1: 'required_format', date_1: :required_date }.sort.to_h, errors.sort.to_h)
    assert_equal({ country_1: { list: 'Usa,india' }, first_1: { list: 'category 1,category 2' },
                   dropdown2_1: { list: 'first11,second22,third33,four44' }, dropdown3_1: { list: 'first,second' }, check2_1: { data_type: 'Boolean' }, check3_1: { data_type: 'Boolean' },
                   dropdown1_1: { list: '1st,2nd' }, dropdown4_1: { list: 'third,fourth' }, check1_1: { data_type: 'Boolean' },
                   number1_1: { data_type: :Integer }, number2_1: { data_type: :Integer }, number3_1: { data_type: :Integer },
                   number4_1: { data_type: :Integer }, single_1: { data_type: String }, single2_1: { data_type: String }, single3_1: { data_type: String },
                   multi_1: { data_type: String }, multi2_1: { data_type: String }, multi3_1: { data_type: String }, phone: { data_type: String },
                   phone_1: { data_type: String }, phone2_1: { data_type: String },
                   check2_1: { data_type: 'Boolean' } }.stringify_keys.sort.to_h, test.error_options.sort.to_h)
  end

  def test_nested_fields_with_changed_child_value
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'new york' })
    refute test.valid?
    CustomFieldValidatorTestHelper.nested_fields_choices_by_name = { second_level_choices: { 'country_1' => { 'Usa' => ['california', 'new york'], 'india' => ['tamil nadu', 'kerala', 'andra pradesh'] }, 'first_1' => { 'category 1' => ['subcategory 1', 'subcategory 2', 'subcategory 3'], 'category 2' => ['subcategory 1'] } } }
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'new york' })
    assert test.valid?
  end

  def test_non_existent_validation_method
    test = TestInvalidTypeValidation.new(attribute1: { 'second_1' => 'fdsfdfs' })
    out, err = capture_io do
      test.valid?
    end
    assert_match %r{validate_junk_field}, err
  end
end
