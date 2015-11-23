require_relative '../unit_test_helper'
require "#{Rails.root}/test/api/helpers/custom_field_validator_test_helper.rb"

class CustomFieldValidatorTest < ActionView::TestCase
  class RequiredTestValidation
    include ActiveModel::Validations

    attr_accessor :attribute3, :attribute4, :error_options, :closed_status, :allow_string_param
    validates :attribute3, :attribute4, custom_field:  { attribute3: {
      validatable_custom_fields: proc { Helpers::CustomFieldValidatorTestHelper.required_choices_validatable_custom_fields },
      drop_down_choices: proc { Helpers::CustomFieldValidatorTestHelper.dropdown_choices_by_field_name },
      nested_field_choices: proc { Helpers::CustomFieldValidatorTestHelper.nested_fields_choices_by_name },
      restrict_api_field_name: true,
      required_based_on_status: proc { |x| x.required_for_closure? },
      required_attribute: :required
    },
                                                         attribute4: {
                                                           validatable_custom_fields: proc { Helpers::CustomFieldValidatorTestHelper.required_data_type_validatable_custom_fields },
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
      validatable_custom_fields: proc { Helpers::CustomFieldValidatorTestHelper.required_closure_choices_validatable_custom_fields },
      drop_down_choices: proc { Helpers::CustomFieldValidatorTestHelper.dropdown_choices_by_field_name },
      nested_field_choices: proc { Helpers::CustomFieldValidatorTestHelper.nested_fields_choices_by_name },
      restrict_api_field_name: true,
      required_based_on_status: proc { |x| x.required_for_closure? },
      required_attribute: :required
    },
                                                         attribute6: {
                                                           validatable_custom_fields: proc { Helpers::CustomFieldValidatorTestHelper.required_closure_data_type_validatable_custom_fields },
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
      validatable_custom_fields: proc { Helpers::CustomFieldValidatorTestHelper.choices_validatable_custom_fields },
      drop_down_choices: proc { Helpers::CustomFieldValidatorTestHelper.dropdown_choices_by_field_name },
      nested_field_choices: proc { Helpers::CustomFieldValidatorTestHelper.nested_fields_choices_by_name },
      required_based_on_status: proc { |x| x.required_for_closure? },
      restrict_api_field_name: true,
      required_attribute: :required
    },
                                                                                                     attribute2: {
                                                                                                       validatable_custom_fields: proc { Helpers::CustomFieldValidatorTestHelper.data_type_validatable_custom_fields },
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
      validatable_custom_fields: [Helpers::CustomFieldValidatorTestHelper.new(id: 14, account_id: 1, api_name: 'second', name: 'second_1', label: 'second', label_in_portal: 'second', description: nil, active: true, field_type: 'junk_field', position: 22, required: false, visible_in_portal: false, editable_in_portal: false, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 4, created_at: '2015-08-10 09:19:28', updated_at: '2015-08-10 14:56:52', field_options: nil, default: false, level: 2, parent_id: 13, prefered_ff_col: nil, import_id: nil)],
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
    assert_equal({ country: :not_included, dropdown2: :not_included, dropdown3: :not_included }.sort.to_h, errors.sort.to_h)
    assert_equal({ country: { list: 'Usa,india' }, dropdown2: { list: 'first11,second22,third33,four44' }, dropdown3: { list: 'first,second' } }.sort.to_h, test.error_options.sort.to_h)
  end

  def test_format_validatable_fields_invalid
    test = TestValidation.new(attribute2: { 'single1' => 'w', 'check1' => 'ds', 'check2' => 'sd', 'decimal1' => 'sds', 'decimal2' => 'sd', 'number1' => 909.898, 'number2' => 'dd', 'multi1' => 'dff', 'url1' => 'udp:/testurl', 'url2' => 'http:/testurl.123' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal(
      {
        check1: :data_type_mismatch, check2: :data_type_mismatch, decimal1: 'is not a number',
        decimal2: 'is not a number', number1: :data_type_mismatch,
        number2: :data_type_mismatch, url1: 'invalid_format', url2: 'invalid_format'
      }.sort.to_h,
      errors.sort.to_h)
    assert_equal({
      check1: { data_type: 'Boolean' },
      check2: { data_type: 'Boolean' },
      number2: { data_type: 'Integer' },
      number1: { data_type: 'Integer' }
    }.sort.to_h, test.error_options.sort.to_h)
  end

  def test_format_validatable_fields_valid
    test = TestValidation.new(attribute1: { 'single1' => 'w', 'check1' => false, 'check2' => true, 'decimal1' => 898, 'decimal2' => 9090, 'number1' => 5656, 'number2' => -787, 'multi1' => 'dff', 'url1' => 'http://testurl.co.test' })
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
    assert_equal({ country: :not_included }, errors)
    assert_equal({ country: { list: 'Usa,india' } }, test.error_options)
  end

  def test_nested_fields_invalid_second_field
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'uiuiu', 'city_1' => 'ww angeles' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ state: :not_included }, errors)
    assert_equal({ state: { list: 'california' } }, test.error_options)
  end

  def test_nested_fields_invalid_third_field
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'california', 'city_1' => 'ddd' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ city: :not_included }, errors)
    assert_equal({ city: { list: 'los angeles,san fransico,san diego' } }, test.error_options)
  end

  def test_nested_fields_without_parent_field_second
    test = TestValidation.new(attribute1: { 'state_1' => 'california', 'city_1' => 'ddd' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ country: :conditional_not_blank }, errors)
    assert_equal({ country: { child: 'state' } }, test.error_options)
  end

  def test_nested_fields_without_parent_field_third
    test = TestValidation.new(attribute1: { 'city_1' => 'ddd' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ country: :conditional_not_blank, state: :conditional_not_blank }.sort.to_h, errors.sort.to_h)
    assert_equal({ country: { child: 'city' }, state: { child: 'city' } }.sort.to_h, test.error_options.sort.to_h)
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
    assert_equal({ country: :required_and_inclusion, first: :required_and_inclusion, check2: :required_boolean, dropdown2: :required_and_inclusion, dropdown1: :required_and_inclusion, check1: :required_boolean, decimal1: 'required_number', decimal2: 'required_number', number1: :required_integer, number2: :required_integer, single1: :missing, multi1: :missing, phone1: :missing, dropdown3: :required_and_inclusion, dropdown4: :required_and_inclusion, check3: :required_boolean, check4: :required_boolean, decimal3: 'required_number', decimal4: 'required_number', multi2: :missing, multi3: :missing, number3: :required_integer, number4: :required_integer, phone1: :missing, phone2: :missing, single2: :missing, single3: :missing, url1: 'required_format', url2: 'required_format', date1: :required_date, phone3: :missing }.sort.to_h, errors.sort.to_h)
    assert_equal({ country: { list: 'Usa,india' }, first: { list: 'category 1,category 2' },
                   dropdown2: { list: 'first11,second22,third33,four44' }, dropdown3: { list: 'first,second' }, check2: { data_type: 'Boolean' }, check3: { data_type: 'Boolean' },
                   dropdown1: { list: '1st,2nd' }, dropdown4: { list: 'third,fourth' }, check1: { data_type: 'Boolean' }, check4: { data_type: 'Boolean' },
                   number1: { data_type: 'Integer' }, number2: { data_type: 'Integer' }, number3: { data_type: 'Integer' },
                   number4: { data_type: 'Integer' },
                   check2: { data_type: 'Boolean' } }.sort.to_h, test.error_options.sort.to_h)
  end

  def test_nested_fields_without_required_closure_fields
    test = RequiredClosureTestValidation.new(closed_status: true)
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ country: :required_and_inclusion, first: :required_and_inclusion, check2: :required_boolean, dropdown2: :required_and_inclusion, dropdown1: :required_and_inclusion, check1: :required_boolean, decimal1: 'required_number', decimal2: 'required_number', number1: :required_integer, number2: :required_integer, single1: :missing, multi1: :missing, phone1: :missing, dropdown3: :required_and_inclusion, dropdown4: :required_and_inclusion, check3: :required_boolean, check4: :required_boolean, decimal3: 'required_number', decimal4: 'required_number', multi2: :missing, multi3: :missing, number3: :required_integer, number4: :required_integer, phone1: :missing, phone2: :missing, single2: :missing, single3: :missing, url1: 'required_format', url2: 'required_format', date1: :required_date, phone3: :missing }.sort.to_h, errors.sort.to_h)
    assert_equal({ country: { list: 'Usa,india' }, first: { list: 'category 1,category 2' },
                   dropdown2: { list: 'first11,second22,third33,four44' }, dropdown3: { list: 'first,second' }, check2: { data_type: 'Boolean' }, check3: { data_type: 'Boolean' },
                   dropdown1: { list: '1st,2nd' }, dropdown4: { list: 'third,fourth' }, check1: { data_type: 'Boolean' }, check4: { data_type: 'Boolean' },
                   number1: { data_type: 'Integer' }, number2: { data_type: 'Integer' }, number3: { data_type: 'Integer' },
                   number4: { data_type: 'Integer' },
                   check2: { data_type: 'Boolean' } }.sort.to_h, test.error_options.sort.to_h)
  end

  def test_nested_fields_with_changed_child_value
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'new york' })
    refute test.valid?
    Helpers::CustomFieldValidatorTestHelper.nested_fields_choices_by_name = { second_level_choices: { 'country_1' => { 'Usa' => ['california', 'new york'], 'india' => ['tamil nadu', 'kerala', 'andra pradesh'] }, 'first_1' => { 'category 1' => ['subcategory 1', 'subcategory 2', 'subcategory 3'], 'category 2' => ['subcategory 1'] } } }
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'new york' })
    assert test.valid?
  end

  def test_non_existent_validation_method
    test = TestInvalidTypeValidation.new(attribute1: { 'second' => 'fdsfdfs' })
    out, err = capture_io do
      test.valid?
    end
    assert_match %r{validate_junk_field}, err
  end
end
