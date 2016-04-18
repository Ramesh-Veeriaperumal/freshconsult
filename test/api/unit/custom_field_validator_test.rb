require_relative '../unit_test_helper'
require "#{Rails.root}/test/api/helpers/custom_field_validator_test_helper.rb"

class CustomFieldValidatorTest < ActionView::TestCase
  class RequiredTestValidation < MockTestValidation
    include ActiveModel::Validations

    attr_accessor :attribute3, :attribute4, :closed_status, :allow_string_param
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
      super
      params.each { |key, value| instance_variable_set("@#{key}", value) }
    end

    def required_for_closure?
      closed_status == true
    end
  end

  class RequiredClosureTestValidation < MockTestValidation
    include ActiveModel::Validations

    attr_accessor :attribute5, :attribute6, :closed_status, :allow_string_param
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
      super
      params.each { |key, value| instance_variable_set("@#{key}", value) }
    end

    def required_for_closure?
      closed_status == true
    end
  end

  class TestValidation < MockTestValidation
    include ActiveModel::Validations

    attr_accessor :attribute1, :attribute2, :closed_status, :allow_string_param

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
      super
      params.each { |key, value| instance_variable_set("@#{key}", value) }
    end

    def required_for_closure?
      closed_status == true
    end
  end

  class TestInvalidTypeValidation < MockTestValidation
    include ActiveModel::Validations

    attr_accessor :attribute1, :closed_status, :allow_string_param

    validates :attribute1, custom_field: { attribute1: {
      validatable_custom_fields: [CustomFieldValidatorTestHelper.new(id: 14, account_id: 1, name: 'second_1', label: 'second', label_in_portal: 'second', description: nil, active: true, field_type: 'junk_field', position: 22, required: false, visible_in_portal: false, editable_in_portal: false, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 4, created_at: '2015-08-10 09:19:28', updated_at: '2015-08-10 14:56:52', field_options: nil, default: false, level: 2, parent_id: 13, prefered_ff_col: nil, import_id: nil)],
      required_based_on_status: proc { |x| x.required_for_closure? },
      required_attribute: :required
    }
                            }

    def initialize(params = {})
      super
      params.each { |key, value| instance_variable_set("@#{key}", value) }
    end

    def required_for_closure?
      closed_status == true
    end
  end

  class SectionFieldTestValidation < MockTestValidation
    include ActiveModel::Validations

    attr_accessor :attribute1, :attribute2, :closed_status, :allow_string_param, :ticket_type, :status, :priority

    validates :ticket_type, custom_inclusion: {in: ['Question', 'Lead', 'Problem']}
    validates :attribute1, :attribute2, data_type: { rules: Hash, allow_nil: true }, custom_field: { attribute1: {
        validatable_custom_fields: proc { CustomFieldValidatorTestHelper.section_field_for_data_type },
        required_based_on_status: proc { |x| x.required_for_closure? },
        required_attribute: :required,
        section_field_mapping: proc{ |x| CustomFieldValidatorTestHelper.section_field_parent_field_mapping_for_data_type }
      },
      attribute2: {
        validatable_custom_fields: proc { CustomFieldValidatorTestHelper.section_field_for_choices },
        drop_down_choices: proc { CustomFieldValidatorTestHelper.dropdown_choices_by_field_name },
        nested_field_choices: proc { CustomFieldValidatorTestHelper.nested_fields_choices_by_name },
        required_based_on_status: proc { |x| x.required_for_closure? },
        required_attribute: :required,
        section_field_mapping: proc{ |x| CustomFieldValidatorTestHelper.section_field_parent_field_mapping_for_choices }
      }
    }


    def initialize(params = {})
      params.each { |key, value| instance_variable_set("@#{key}", value) }
	  check_params_set(params[:attribute1]) if params[:attribute1].is_a?(Hash)
      check_params_set(params[:attribute2]) if params[:attribute2].is_a?(Hash)
      super
    end

    def required_for_closure?
      closed_status == true
    end
  end

  class SectionFieldTestRequiredValidation < MockTestValidation
    include ActiveModel::Validations

    attr_accessor :attribute1, :attribute2, :closed_status, :allow_string_param, :ticket_type, :status, :priority

    validates :ticket_type, custom_inclusion: {in: ['Question', 'Lead', 'Problem']}
    validates :attribute1, :attribute2, data_type: { rules: Hash, allow_nil: true }, custom_field: { attribute1: {
        validatable_custom_fields: proc { CustomFieldValidatorTestHelper.section_field_for_data_type_required },
        required_based_on_status: proc { |x| x.required_for_closure? },
        required_attribute: :required,
        section_field_mapping: proc{ |x| CustomFieldValidatorTestHelper.section_field_parent_field_mapping_for_data_type }
      },
      attribute2: {
        validatable_custom_fields: proc { CustomFieldValidatorTestHelper.section_field_for_choices_required },
        drop_down_choices: proc { CustomFieldValidatorTestHelper.dropdown_choices_by_field_name },
        nested_field_choices: proc { CustomFieldValidatorTestHelper.nested_fields_choices_by_name },
        required_based_on_status: proc { |x| x.required_for_closure? },
        required_attribute: :required,
        section_field_mapping: proc{ |x| CustomFieldValidatorTestHelper.section_field_parent_field_mapping_for_choices }
      }
    }


    def initialize(params = {})
      params.each { |key, value| instance_variable_set("@#{key}", value) }
	  check_params_set(params[:attribute1]) if params[:attribute1].is_a?(Hash)
      check_params_set(params[:attribute2]) if params[:attribute2].is_a?(Hash)
      super
    end

    def required_for_closure?
      closed_status == true
    end
  end

  def setup
    account = mock
    account.stubs(:id).returns(1)
    Account.stubs(:current).returns(account)
    super
  end

  def teardown
    Account.unstub(:current)
    super
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
    assert_equal({ country_1: :not_included, dropdown2_1: :not_included, dropdown3_1: :not_included }, errors)
    assert_equal({ country_1: { list: '...,Usa,india' }, dropdown2_1: { list: 'first11,second22,third33,four44' }, dropdown3_1: { list: 'first,second' } }.stringify_keys.merge(attribute1: {}), test.error_options)
  end

  def test_format_validatable_fields_invalid
    test = TestValidation.new(attribute2: { 'single_1' => [1, 2], 'check1_1' => 'ds', 'check2_1' => nil, 'decimal1_1' => 'sds', 'phone' => 3.4, 'decimal2_1' => 'sd', 'number1_1' => false, 'number2_1' => 'dd', 'multi_1' => 9.0, 'url1_1' => 'udp:/testurl', 'url2_1' => 'http:/testurl.123' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal(
      {
        check1_1: :datatype_mismatch, single_1: :datatype_mismatch, multi_1: :datatype_mismatch, phone: :datatype_mismatch, check2_1: :datatype_mismatch, decimal1_1: :datatype_mismatch,
        decimal2_1: :datatype_mismatch, number1_1: :datatype_mismatch,
        number2_1: :datatype_mismatch, url1_1: :invalid_format, url2_1: :invalid_format
      },
      errors)
    assert_equal({ 'single_1' => { expected_data_type: String, prepend_msg: :input_received, given_data_type: Array }, 'check1_1' => { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String }, 'check2_1' => { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: 'Null' }, 'decimal1_1' => { expected_data_type: :Number }, 'decimal2_1' => { expected_data_type: :Number }, 'number1_1' => { expected_data_type: :Integer, prepend_msg: :input_received, given_data_type: 'Boolean' }, 'number2_1' => { expected_data_type: :Integer, prepend_msg: :input_received, given_data_type: String }, 'multi_1' => { expected_data_type: String, prepend_msg: :input_received, given_data_type: Float }, 'phone' => { expected_data_type: String, prepend_msg: :input_received, given_data_type: Float }, 'url1_1' => { accepted: 'valid URL' }, 'url2_1' => { accepted: 'valid URL' } }.stringify_keys.merge(attribute2: {}), test.error_options)
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
    assert_equal({ country_1: { list: '...,Usa,india' } }.stringify_keys.merge(attribute1: {}), test.error_options)
  end

  def test_nested_fields_invalid_second_field
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'uiuiu', 'city_1' => 'ww angeles' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ state_1: :not_included }, errors)
    assert_equal({ state_1: { list: 'california' }, country_1: {} }.stringify_keys.merge(attribute1: {}), test.error_options)
  end

  def test_nested_fields_invalid_third_field
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'california', 'city_1' => 'ddd' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ city_1: :not_included }, errors)
    assert_equal({ city_1: { list: 'los angeles,san fransico,san diego' }, state_1: {}, country_1: {} }.stringify_keys.merge(attribute1: {}), test.error_options)
  end

  def test_nested_fields_same_second_level_choice_invalid
    test = TestValidation.new(attribute1: { 'first_1' => 'category 1', 'second_1' => 'subcategory 1', 'third_1' => '123' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ third_1: :not_included }, errors)
    assert_equal({ third_1: { list: 'abc,def' }, second_1: {}, first_1: {} }.stringify_keys.merge(attribute1: {}), test.error_options)
  end

  def test_nested_fields_with_second_value_with_no_choices
    test = TestValidation.new(attribute1: { 'country_1' => '...', 'state_1' => 'ddd', 'city_1' => '123' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ state_1: :should_be_blank }, errors)
  end

  def test_nested_fields_with_blank_second_value_with_no_choices
    test = TestValidation.new(attribute1: { 'country_1' => '...', 'state_1' => '', 'city_1' => '123' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ state_1: :should_be_blank }, errors)
  end

  def test_nested_fields_same_second_level_choice_valid
    test = TestValidation.new(attribute1: { 'first_1' => 'category 1', 'second_1' => 'subcategory 1', 'third_1' => 'abc' })
    assert test.valid?
  end

  def test_nested_fields_without_parent_field_second
    acc = Account.new
    acc.id = 1
    Account.stubs(:current).returns(acc)
    test = TestValidation.new(attribute1: { 'state_1' => 'california', 'city_1' => 'ddd' })
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ country_1: :conditional_not_blank }, errors)
    assert_equal({ 'country_1' => { child: 'state' }, attribute1: {} }, test.error_options)
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
    assert_equal({ country_1: :conditional_not_blank, state_1: :conditional_not_blank }, errors)
    assert_equal({ country_1: { child: 'city' }, state_1: { child: 'city' } }.stringify_keys.merge(attribute1: {}), test.error_options)
  ensure
    Account.unstub(:current)
  end

  def test_attribute_with_errors
    test = TestValidation.new(attribute1: 'Junk string 1', attribute2: 'junk string 2')
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ attribute1: :datatype_mismatch, attribute2: :datatype_mismatch }, errors)
    assert errors.count == 2
  end

  def test_nested_fields_without_required_fields
    test = RequiredTestValidation.new
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ check1_1: :datatype_mismatch, check2_1: :datatype_mismatch, check3_1: :datatype_mismatch,
                   country_1: :not_included, date_1: :invalid_date, decimal1_1: :datatype_mismatch,
                   decimal2_1: :datatype_mismatch, decimal3_1: :datatype_mismatch, decimal4_1: :datatype_mismatch,
                   dropdown1_1: :not_included, dropdown2_1: :not_included, dropdown3_1: :not_included,
                   dropdown4_1: :not_included, first_1: :not_included, multi2_1: :datatype_mismatch,
                   multi3_1: :datatype_mismatch, multi_1: :datatype_mismatch, number1_1: :datatype_mismatch,
                   number2_1: :datatype_mismatch, number3_1: :datatype_mismatch, number4_1: :datatype_mismatch,
                   phone: :datatype_mismatch, phone2_1: :datatype_mismatch, phone_1: :datatype_mismatch,
                   single2_1: :datatype_mismatch, single3_1: :datatype_mismatch, single_1: :datatype_mismatch,
                   url1_1: :invalid_format, url2_1: :invalid_format }, errors)
    assert_equal({ country_1: { list: '...,Usa,india', code: :missing_field }, first_1: { list: 'category 1,category 2', code: :missing_field }, dropdown1_1: { list: '1st,2nd', code: :missing_field }, dropdown2_1: { list: 'first11,second22,third33,four44', code: :missing_field }, dropdown3_1: { list: 'first,second', code: :missing_field }, dropdown4_1: { list: 'third,fourth', code: :missing_field }, single_1: { expected_data_type: String, code: :missing_field }, single2_1: { expected_data_type: String, code: :missing_field }, single3_1: { expected_data_type: String, code: :missing_field }, check1_1: { expected_data_type: 'Boolean', code: :missing_field }, check2_1: { expected_data_type: 'Boolean', code: :missing_field }, check3_1: { expected_data_type: 'Boolean', code: :missing_field }, decimal1_1: { expected_data_type: :Number, code: :missing_field }, decimal2_1: { expected_data_type: :Number, code: :missing_field }, decimal3_1: { expected_data_type: :Number, code: :missing_field }, decimal4_1: { expected_data_type: :Number, code: :missing_field }, number1_1: { expected_data_type: :Integer, code: :missing_field }, number2_1: { expected_data_type: :Integer, code: :missing_field }, number3_1: { expected_data_type: :Integer, code: :missing_field }, number4_1: { expected_data_type: :Integer, code: :missing_field }, multi_1: { expected_data_type: String, code: :missing_field }, multi2_1: { expected_data_type: String, code: :missing_field }, multi3_1: { expected_data_type: String, code: :missing_field }, phone: { expected_data_type: String, code: :missing_field }, phone_1: { expected_data_type: String, code: :missing_field }, phone2_1: { expected_data_type: String, code: :missing_field }, url1_1: { accepted: 'valid URL', code: :missing_field }, url2_1: { accepted: 'valid URL', code: :missing_field }, date_1: { accepted: :'yyyy-mm-dd', code: :missing_field } }.stringify_keys, test.error_options)
  end

  def test_nested_fields_without_required_closure_fields
    test = RequiredClosureTestValidation.new(closed_status: true)
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ check1_1: :datatype_mismatch, check2_1: :datatype_mismatch, check3_1: :datatype_mismatch,
                   country_1: :not_included, date_1: :invalid_date, decimal1_1: :datatype_mismatch,
                   decimal2_1: :datatype_mismatch, decimal3_1: :datatype_mismatch, decimal4_1: :datatype_mismatch,
                   dropdown1_1: :not_included, dropdown2_1: :not_included, dropdown3_1: :not_included,
                   dropdown4_1: :not_included, first_1: :not_included, multi2_1: :datatype_mismatch,
                   multi3_1: :datatype_mismatch, multi_1: :datatype_mismatch, number1_1: :datatype_mismatch,
                   number2_1: :datatype_mismatch, number3_1: :datatype_mismatch, number4_1: :datatype_mismatch,
                   phone: :datatype_mismatch, phone2_1: :datatype_mismatch, phone_1: :datatype_mismatch,
                   single2_1: :datatype_mismatch, single3_1: :datatype_mismatch, single_1: :datatype_mismatch,
                   url1_1: :invalid_format, url2_1: :invalid_format }, errors)
    assert_equal({ country_1: { list: '...,Usa,india', code: :missing_field }, first_1: { list: 'category 1,category 2', code: :missing_field }, dropdown1_1: { list: '1st,2nd', code: :missing_field }, dropdown2_1: { list: 'first11,second22,third33,four44', code: :missing_field }, dropdown3_1: { list: 'first,second', code: :missing_field }, dropdown4_1: { list: 'third,fourth', code: :missing_field }, single_1: { expected_data_type: String, code: :missing_field }, single2_1: { expected_data_type: String, code: :missing_field }, single3_1: { expected_data_type: String, code: :missing_field }, check1_1: { expected_data_type: 'Boolean', code: :missing_field }, check2_1: { expected_data_type: 'Boolean', code: :missing_field }, check3_1: { expected_data_type: 'Boolean', code: :missing_field }, decimal1_1: { expected_data_type: :Number, code: :missing_field }, decimal2_1: { expected_data_type: :Number, code: :missing_field }, decimal3_1: { expected_data_type: :Number, code: :missing_field }, decimal4_1: { expected_data_type: :Number, code: :missing_field }, number1_1: { expected_data_type: :Integer, code: :missing_field }, number2_1: { expected_data_type: :Integer, code: :missing_field }, number3_1: { expected_data_type: :Integer, code: :missing_field }, number4_1: { expected_data_type: :Integer, code: :missing_field }, multi_1: { expected_data_type: String, code: :missing_field }, multi2_1: { expected_data_type: String, code: :missing_field }, multi3_1: { expected_data_type: String, code: :missing_field }, phone: { expected_data_type: String, code: :missing_field }, phone_1: { expected_data_type: String, code: :missing_field }, phone2_1: { expected_data_type: String, code: :missing_field }, url1_1: { accepted: 'valid URL', code: :missing_field }, url2_1: { accepted: 'valid URL', code: :missing_field }, date_1: { accepted: :'yyyy-mm-dd', code: :missing_field } }.stringify_keys, test.error_options)
  end

  def test_nested_fields_with_changed_child_value
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'new york' })
    refute test.valid?
    CustomFieldValidatorTestHelper.nested_fields_choices_by_name = { 'country_1' => { '...' => {}, 'Usa' => { 'california' =>  ['los angeles', 'san fransico', 'san diego'], 'new york' => [] }, 'india' => { 'tamil nadu' => ['chennai', 'trichy'], 'kerala' => [], 'andra pradesh' => ['hyderabad', 'vizag'] } },
                                                                     'first_1' =>  { 'category 1' => { 'subcategory 1' => ['abc', 'def'], 'subcategory 2' => ['mno', 'pqr'], 'subcategory 3' => [] }, 'category 2' => { 'subcategory 1' => ['123', '456'] } } }
    test = TestValidation.new(attribute1: { 'country_1' => 'Usa', 'state_1' => 'new york' })
    assert test.valid?
  end

  def test_section_field_validation_for_data_type_absence_error
    account = mock
    account.stubs(:id).returns(1)
    Account.stubs(:current).returns(account)
    test = SectionFieldTestValidation.new(ticket_type: 'Problem', status: 3, priority: 4, attribute1: {'single_1' => "jkj", 'check1_1' => false, 'check2_1' => true, 'date_1' => Time.now.zone.to_s, 'url1_1' => "gh", 'phone' => "dasfdf", 'multi2_1' => "efsdff", 'number1_1' => 23, 'decimal2_1' => "12.4"})
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({single_1: :section_field_absence_check_error, check1_1: :section_field_absence_check_error, check2_1: :section_field_absence_check_error, date_1: :section_field_absence_check_error, url1_1: :section_field_absence_check_error, phone: :section_field_absence_check_error, multi2_1: :section_field_absence_check_error, number1_1: :section_field_absence_check_error, decimal2_1: :section_field_absence_check_error}.sort.to_h, errors.sort.to_h)
  end

  def test_section_field_validation_for_choices_absence_error
    test = SectionFieldTestValidation.new(ticket_type: 'Problem', status: 3, priority: 4, attribute2: {'dropdown1_1' => "ewee", 'first_1' => "fsdfsdf", 'country_1' => "ewrewtrwer"})
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({dropdown1_1: :section_field_absence_check_error, first_1: :section_field_absence_check_error, country_1: :section_field_absence_check_error}.sort.to_h, errors.sort.to_h)
  end

  def test_section_field_validation_for_choices_required
    test = SectionFieldTestRequiredValidation.new(ticket_type: 'Question', status: 2, priority: 3, attribute1: {'single_1' => "jkj", 'check1_1' => true, 'check2_1' => false, 'date_1' =>'2011-09-12', 'phone' => "35345346dgdf", 'multi2_1' => "efsdff"})
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({dropdown1_1: :not_included, first_1: :not_included, country_1: :not_included}.sort.to_h, errors.sort.to_h)
  end

   def test_section_field_validation_for_data_type_required
    test = SectionFieldTestRequiredValidation.new(ticket_type: 'Question', status: 2, priority: 3, attribute2: {'dropdown1_1' => "1st", 'first_1' => "category 1", 'country_1' => "Usa"})
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({single_1: :datatype_mismatch, check1_1: :datatype_mismatch, check2_1: :datatype_mismatch, date_1: :invalid_date, phone: :datatype_mismatch, multi2_1: :datatype_mismatch}.sort.to_h, errors.sort.to_h)
  end

  def test_section_field_validation_for_data_type_invalid
    account = mock
    account.stubs(:id).returns(1)
    Account.stubs(:current).returns(account)
    test = SectionFieldTestValidation.new(ticket_type: 'Question', status: 2, priority: 3, attribute1: {'single_1' => 12, 'check1_1' => "true", 'date_1' => "sdd", 'phone' => [12,34], 'multi2_1' => 23})
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({single_1: :datatype_mismatch, check1_1: :datatype_mismatch, date_1: :invalid_date, phone: :datatype_mismatch, multi2_1: :datatype_mismatch}.sort.to_h, errors.sort.to_h)
  end

  def test_section_field_validation_for_choices_invalid
    test = SectionFieldTestValidation.new(ticket_type: 'Question', status: 2, priority: 3, attribute2: {'dropdown1_1' => "ewee", 'first_1' => "fsdfsdf", 'country_1' => "ewrewtrwer"})
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({dropdown1_1: :not_included, first_1: :not_included, country_1: :not_included}.sort.to_h, errors.sort.to_h)
  end

  def test_section_field_validation_for_data_type_invalid_with_parent_invalid
    account = mock
    account.stubs(:id).returns(1)
    Account.stubs(:current).returns(account)
    test = SectionFieldTestValidation.new('ticket_type' => 'QuestionType', attribute1: {'single_1' => "jkj", 'check1_1' => true, 'check2_1' => false, 'date_1' => Time.now.zone.to_s, 'url1_1' => "gh", 'phone' => "dasfdf", 'multi2_1' => "efsdff", 'number1_1' => 23, 'decimal2_1' => "12.4"})
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ticket_type: :not_included}.sort.to_h, errors.sort.to_h)
  end

   def test_section_field_validation_for_choices_invalid_with_parent_invalid
    test = SectionFieldTestValidation.new('ticket_type' => 'QuestionType', attribute2: {'dropdown1_1' => "ewee", 'first_1' => "fsdfsdf", 'country_1' => "ewrewtrwer"})
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ticket_type: :not_included}.sort.to_h, errors.sort.to_h)
  end

  def test_section_field_validation_for_choices_required_with_parent_invalid
    test = SectionFieldTestRequiredValidation.new('ticket_type' => 'QuestionType', attribute1: {'single_1' => "jkj", 'check1_1' => true, 'check2_1' => false, 'date_1' =>'2011-09-12', 'phone' => "35345346dgdf", 'multi2_1' => "efsdff"})
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ticket_type: :not_included}.sort.to_h, errors.sort.to_h)
  end

   def test_section_field_validation_for_data_type_required_with_parent_invalid
    test = SectionFieldTestRequiredValidation.new('ticket_type' => 'QuestionType', attribute2: {'dropdown1_1' => "1st", 'first_1' => "category 1", 'country_1' => "Usa"})
    refute test.valid?
    errors = test.errors.to_h
    assert_equal({ticket_type: :not_included}.sort.to_h, errors.sort.to_h)
  end

  def test_non_existent_validation_method
    test = TestInvalidTypeValidation.new(attribute1: { 'second_1' => 'fdsfdfs' })
    out, err = capture_io do
      test.valid?
    end
    assert_match %r{validate_junk_field}, err
  end
end
