require_relative '../unit_test_helper'
require "#{Rails.root}/test/api/helpers/custom_field_validator_helper.rb"

class CustomFieldValidatorTest < ActionView::TestCase
  class RequiredTestValidation
    include ActiveModel::Validations

    attr_accessor :attribute3, :attribute4, :error_options, :closed_status
    validates :attribute3, :attribute4, custom_field:  { attribute3: {
      validatable_custom_fields: proc { Helpers::CustomFieldValidatorHelper.required_choices_validatable_custom_fields },
      drop_down_choices: proc { Helpers::CustomFieldValidatorHelper.dropdown_choices_by_field_name },
      nested_field_choices: proc { Helpers::CustomFieldValidatorHelper.nested_fields_choices_by_name },
      required_based_on_status: proc { |x| x.required_for_closure? },
      required_attribute: :required
    },
                                                         attribute4: {
                                                           validatable_custom_fields: proc { Helpers::CustomFieldValidatorHelper.required_data_type_validatable_custom_fields },
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

    attr_accessor :attribute5, :attribute6, :error_options, :closed_status
    validates :attribute5, :attribute6, custom_field:  { attribute5: {
      validatable_custom_fields: proc { Helpers::CustomFieldValidatorHelper.required_closure_choices_validatable_custom_fields },
      drop_down_choices: proc { Helpers::CustomFieldValidatorHelper.dropdown_choices_by_field_name },
      nested_field_choices: proc { Helpers::CustomFieldValidatorHelper.nested_fields_choices_by_name },
      required_based_on_status: proc { |x| x.required_for_closure? },
      required_attribute: :required
    },
                                                         attribute6: {
                                                           validatable_custom_fields: proc { Helpers::CustomFieldValidatorHelper.required_closure_data_type_validatable_custom_fields },
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

    attr_accessor :attribute1, :attribute2, :error_options, :closed_status

    validates :attribute1, :attribute2, custom_field: { attribute1: {
      validatable_custom_fields: proc { Helpers::CustomFieldValidatorHelper.choices_validatable_custom_fields },
      drop_down_choices: proc { Helpers::CustomFieldValidatorHelper.dropdown_choices_by_field_name },
      nested_field_choices: proc { Helpers::CustomFieldValidatorHelper.nested_fields_choices_by_name },
      required_based_on_status: proc { |x| x.required_for_closure? },
      required_attribute: :required
    },
                                                        attribute2: {
                                                          validatable_custom_fields: proc { Helpers::CustomFieldValidatorHelper.data_type_validatable_custom_fields },
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
    test = TestValidation.new(attribute1: { 'country_1' => 'klk', 'dropdown2_1' => 'jkjk' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ country_1: 'not_included', dropdown2_1: 'not_included' }.sort.to_h, errors.sort.to_h)
    assert_equal({ country_1: { list: 'Usa,india' }, dropdown2_1: { list: 'first11,second22,third33,four44' } }.sort.to_h, test.error_options.sort.to_h)
  end

  def test_format_validatable_fields_invalid
    test = TestValidation.new(attribute2: { 'single_1' => 'w', 'check1_1' => 'ds', 'check2_1' => 'sd', 'decimal1_1' => 'sds', 'decimal2_1' => 'sd', 'number1_1' => 909.898, 'number2_1' => 'dd', 'multi_1' => 'dff' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal(
      {
        check1_1: 'data_type_mismatch', check2_1: 'data_type_mismatch', decimal1_1: 'is not a number',
        decimal2_1: 'is not a number', number1_1: 'data_type_mismatch',
        number2_1: 'data_type_mismatch'
      }.sort.to_h,
      errors.sort.to_h)
    assert_equal({
      check1_1: { data_type: 'Boolean' },
      check2_1: { data_type: 'Boolean' },
      number2_1: { data_type: 'Integer' },
      number1_1: { data_type: 'Integer' }
    }.sort.to_h, test.error_options.sort.to_h)
  end

  def test_format_validatable_fields_valid
    test = TestValidation.new(attribute1: { 'single_1' => 'w', 'check1_1' => false, 'check2_1' => true, 'decimal1_1' => 898, 'decimal2_1' => 9090, 'number1_1' => 5656, 'number2_1' => -787, 'multi_1' => 'dff' })
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
    assert_equal({ country_1: 'not_included' }, errors)
    assert_equal({ country_1: { list: 'Usa,india' } }, test.error_options)
  end

  def test_nested_fields_invalid_second_field
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'uiuiu', 'city_1' => 'ww angeles' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ state_1: 'not_included' }, errors)
    assert_equal({ state_1: { list: 'california' } }, test.error_options)
  end

  def test_nested_fields_invalid_third_field
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'california', 'city_1' => 'ddd' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ city_1: 'not_included' }, errors)
    assert_equal({ city_1: { list: 'los angeles,san fransico,san diego' } }, test.error_options)
  end

  def test_nested_fields_without_parent_field_second
    test = TestValidation.new(attribute1: { 'state_1' => 'california', 'city_1' => 'ddd' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ country_1: 'conditional_not_blank' }, errors)
    assert_equal({ country_1: { child: 'state_1' } }, test.error_options)
  end

  def test_nested_fields_without_parent_field_third
    test = TestValidation.new(attribute1: { 'city_1' => 'ddd' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ country_1: 'conditional_not_blank', state_1: 'conditional_not_blank' }.sort.to_h, errors.sort.to_h)
    assert_equal({ country_1: { child: 'city_1' }, state_1: { child: 'city_1' } }.sort.to_h, test.error_options.sort.to_h)
  end

  def test_nested_fields_without_required_fields
    test = RequiredTestValidation.new
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ country_1: 'required_and_inclusion', first_1: 'required_and_inclusion', check2_1: 'required_boolean', dropdown2_1: 'required_and_inclusion', dropdown1_1: 'required_and_inclusion', check1_1: 'required_boolean', decimal1_1: 'required_number', decimal2_1: 'required_number', number1_1: 'required_integer', number2_1: 'required_integer', single_1: 'missing', multi_1: 'missing' }.sort.to_h, errors.sort.to_h)
    assert_equal({ country_1: { list: 'Usa,india' }, first_1: { list: 'category 1,category 2' },
                   dropdown2_1: { list: 'first11,second22,third33,four44' },
                   dropdown1_1: { list: '1st,2nd' }, check1_1: { data_type: 'Boolean' },
                   number1_1: { data_type: 'Integer' }, number2_1: { data_type: 'Integer' },
                   check2_1: { data_type: 'Boolean' } }.sort.to_h, test.error_options.sort.to_h)
  end

  def test_nested_fields_without_required_closure_fields
    test = RequiredClosureTestValidation.new(closed_status: true)
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ country_1: 'required_and_inclusion', first_1: 'required_and_inclusion', check2_1: 'required_boolean', dropdown2_1: 'required_and_inclusion', dropdown1_1: 'required_and_inclusion', check1_1: 'required_boolean', decimal1_1: 'required_number', decimal2_1: 'required_number', number1_1: 'required_integer', number2_1: 'required_integer', single_1: 'missing', multi_1: 'missing' }.sort.to_h, errors.sort.to_h)
    assert_equal({ country_1: { list: 'Usa,india' }, first_1: { list: 'category 1,category 2' },
                   dropdown2_1: { list: 'first11,second22,third33,four44' },
                   dropdown1_1: { list: '1st,2nd' }, check1_1: { data_type: 'Boolean' },
                   number1_1: { data_type: 'Integer' }, number2_1: { data_type: 'Integer' },
                   check2_1: { data_type: 'Boolean' } }.sort.to_h, test.error_options.sort.to_h)
  end

  def test_nested_fields_with_changed_child_value
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'new york' })
    refute test.valid?
    Helpers::CustomFieldValidatorHelper.nested_fields_choices_by_name = {second_level_choices: { 'country_1' => { 'Usa' => ['california', 'new york'], 'india' => ['tamil nadu', 'kerala', 'andra pradesh'] }, 'first_1' => { 'category 1' => ['subcategory 1', 'subcategory 2', 'subcategory 3'], 'category 2' => ['subcategory 1'] } }}
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'new york' })
    assert test.valid?
  end

  def test_non_existent_validation_method
  end
end
