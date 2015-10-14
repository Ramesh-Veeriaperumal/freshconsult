class Helpers::CustomFieldValidatorHelper
  attr_accessor :id, :nested_fields_choices_by_name, :account_id, :name, :label, :label_in_portal, :description, :active, :field_type, :position, :required, :visible_in_portal, :editable_in_portal, :required_in_portal, :required_for_closure, :flexifield_def_entry_id, :created_at, :updated_at, :field_options, :default, :level, :parent_id, :prefered_ff_col, :import_id

  NESTED_CHOICES = {
    first_level_choices: { 'country_1' => ['Usa', 'india'], 'first_1' => ['category 1', 'category 2'] },
    second_level_choices: { 'country_1' => { 'Usa' => ['california'], 'india' => ['tamil nadu', 'kerala', 'andra pradesh'] }, 'first_1' => { 'category 1' => ['subcategory 1', 'subcategory 2', 'subcategory 3'], 'category 2' => ['subcategory 1'] } },
    third_level_choices: { 'country_1' => { 'california' => ['los angeles', 'san fransico', 'san diego'], 'tamil nadu' => ['chennai', 'trichy'], 'kerala' => [], 'andra pradesh' => ['hyderabad', 'vizag'] }, 'first_1' => { 'subcategory 1' => ['item 1', 'item 2'], 'subcategory 2' => ['item 1', 'item 2'], 'subcategory 3' => [] } }
  }

  def initialize(params = {})
    params.each { |key, value| instance_variable_set("@#{key}", value) }
  end

  class << self
    @@nested_choices = NESTED_CHOICES
    def choices_validatable_custom_fields
      [
        Helpers::CustomFieldValidatorHelper.new(id: 14, account_id: 1, name: 'second_1', label: 'second', label_in_portal: 'second', description: nil, active: true, field_type: 'nested_field', position: 22, required: false, visible_in_portal: false, editable_in_portal: false, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 4, created_at: '2015-08-10 09:19:28', updated_at: '2015-08-10 14:56:52', field_options: nil, default: false, level: 2, parent_id: 13, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 15, account_id: 1, name: 'third_1', label: 'third', label_in_portal: 'third', description: nil, active: true, field_type: 'nested_field', position: 23, required: false, visible_in_portal: false, editable_in_portal: false, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 5, created_at: '2015-08-10 09:19:28', updated_at: '2015-08-10 14:56:52', field_options: nil, default: false, level: 3, parent_id: 13, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 21, account_id: 1, name: 'state_1', label: 'state', label_in_portal: 'state', description: nil, active: true, field_type: 'nested_field', position: 24, required: false, visible_in_portal: false, editable_in_portal: false, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 11, created_at: '2015-08-10 09:24:35', updated_at: '2015-08-10 09:53:16', field_options: nil, default: false, level: 2, parent_id: 20, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 22, account_id: 1, name: 'city_1', label: 'city', label_in_portal: 'city', description: nil, active: true, field_type: 'nested_field', position: 25, required: false, visible_in_portal: false, editable_in_portal: false, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 12, created_at: '2015-08-10 09:24:36', updated_at: '2015-08-10 09:53:16', field_options: nil, default: false, level: 3, parent_id: 20, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 20, account_id: 1, name: 'country_1', label: 'country', label_in_portal: 'country', description: '', active: true, field_type: 'nested_field', position: 3, required: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 10, created_at: '2015-08-10 09:24:33', updated_at: '2015-08-10 09:53:15', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 13, account_id: 1, name: 'first_1', label: 'first', label_in_portal: 'first', description: '', active: true, field_type: 'nested_field', position: 9, required: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 3, created_at: '2015-08-10 09:19:27', updated_at: '2015-08-10 14:56:51', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 17, account_id: 1, name: 'dropdown1_1', label: 'dropdown1', label_in_portal: 'dropdown1', description: '', active: true, field_type: 'custom_dropdown', position: 11, required: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 7, created_at: '2015-08-10 09:19:28', updated_at: '2015-08-10 09:24:42', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 25, account_id: 1, name: 'dropdown2_1', label: 'dropdown2', label_in_portal: 'dropdown2', description: '', active: true, field_type: 'custom_dropdown', position: 7, required: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: true, flexifield_def_entry_id: 15, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 29, account_id: 1, name: 'dropdown_3', label: 'dropdown_3', field_type: 'custom_dropdown', position: 29, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, company_form_id: 1, required_for_agent: false),
        Helpers::CustomFieldValidatorHelper.new(id: 30, account_id: 1, name: 'dropdown_4', label: 'dropdown_4', label_in_portal: 'dropdown4', field_type: 'custom_dropdown', position: 30, required_for_agent: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, contact_form_id: 1)
      ]
    end

    def data_type_validatable_custom_fields
      [
        Helpers::CustomFieldValidatorHelper.new(id: 11, account_id: 1, name: 'single_1', label: 'single', label_in_portal: 'single', description: '', active: true, field_type: 'custom_text', position: 2, required: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 1, created_at: '2015-08-10 09:19:26', updated_at: '2015-08-11 05:40:01', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 31, account_id: 1, name: 'single_2', label: 'single_2', field_type: 'custom_text', position: 31, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, company_form_id: 1, required_for_agent: false),
        Helpers::CustomFieldValidatorHelper.new(id: 32, account_id: 1, name: 'single_3', label: 'single_3', label_in_portal: 'single_3', field_type: 'custom_text', position: 32, required_for_agent: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, contact_form_id: 1),
        Helpers::CustomFieldValidatorHelper.new(id: 12, account_id: 1, name: 'check1_1', label: 'check1', label_in_portal: 'check1', description: '', active: true, field_type: 'custom_checkbox', position: 6, required: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 2, created_at: '2015-08-10 09:19:26', updated_at: '2015-08-10 09:24:39', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 33, account_id: 1, name: 'check_2', label: 'check_2', field_type: 'custom_checkbox', position: 33, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, company_form_id: 1, required_for_agent: false),
        Helpers::CustomFieldValidatorHelper.new(id: 34, account_id: 1, name: 'check_3', label: 'check_3', label_in_portal: 'check_3', field_type: 'custom_checkbox', position: 34, required_for_agent: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, contact_form_id: 1),
        Helpers::CustomFieldValidatorHelper.new(id: 23, account_id: 1, name: 'check2_1', label: 'check2', label_in_portal: 'check2', description: '', active: true, field_type: 'custom_checkbox', position: 4, required: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 13, created_at: '2015-08-10 09:24:36', updated_at: '2015-08-10 09:24:37', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 16, account_id: 1, name: 'decimal1_1', label: 'decimal1', label_in_portal: 'decimal1', description: '', active: true, field_type: 'custom_decimal', position: 10, required: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 6, created_at: '2015-08-10 09:19:28', updated_at: '2015-08-10 09:24:41', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 24, account_id: 1, name: 'decimal2_1', label: 'decimal2', label_in_portal: 'decimal2', description: '', active: true, field_type: 'custom_decimal', position: 5, required: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 14, created_at: '2015-08-10 09:24:38', updated_at: '2015-08-10 09:24:38', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 35, account_id: 1, name: 'decimal_3', label: 'decimal_3', field_type: 'custom_decimal', position: 35, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, company_form_id: 1, required_for_agent: false),
        Helpers::CustomFieldValidatorHelper.new(id: 36, account_id: 1, name: 'decimal_4', label: 'decimal_4', label_in_portal: 'decimal_4', field_type: 'custom_decimal', position: 36, required_for_agent: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, contact_form_id: 1),
        Helpers::CustomFieldValidatorHelper.new(id: 18, account_id: 1, name: 'number1_1', label: 'number1', label_in_portal: 'number1', description: '', active: true, field_type: 'custom_number', position: 12, required: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 8, created_at: '2015-08-10 09:19:29', updated_at: '2015-08-10 09:24:42', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 26, account_id: 1, name: 'number2_1', label: 'number2', label_in_portal: 'number2', description: '', active: true, field_type: 'custom_number', position: 8, required: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 16, created_at: '2015-08-10 09:24:40', updated_at: '2015-08-11 05:40:02', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 37, account_id: 1, name: 'number_3', label: 'number_3', field_type: 'custom_number', position: 37, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, company_form_id: 1, required_for_agent: false),
        Helpers::CustomFieldValidatorHelper.new(id: 38, account_id: 1, name: 'number_4', label: 'number_4', label_in_portal: 'number_3', field_type: 'custom_number', position: 38, required_for_agent: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, contact_form_id: 1),
        Helpers::CustomFieldValidatorHelper.new(id: 19, account_id: 1, name: 'multi_1', label: 'multi', label_in_portal: 'multi', description: '', active: true, field_type: 'custom_paragraph', position: 14, required: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 9, created_at: '2015-08-10 09:19:29', updated_at: '2015-08-10 09:24:42', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 39, account_id: 1, name: 'multi_2', label: 'multi_2', field_type: 'custom_paragraph', position: 39, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, company_form_id: 1, required_for_agent: false),
        Helpers::CustomFieldValidatorHelper.new(id: 40, account_id: 1, name: 'multi_3', label: 'multi_3', label_in_portal: 'multi_3', field_type: 'custom_paragraph', position: 40, required_for_agent: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, contact_form_id: 1),
        Helpers::CustomFieldValidatorHelper.new(id: 27, account_id: 1, name: 'phone', label: 'phone', label_in_portal: 'phone', description: '', active: true, field_type: 'custom_phone_number', position: 27, required: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 1, created_at: '2015-08-10 09:19:26', updated_at: '2015-08-11 05:40:01', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::CustomFieldValidatorHelper.new(id: 41, account_id: 1, name: 'phone_1', label: 'phone_1', field_type: 'custom_phone_number', position: 41, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, company_form_id: 1, required_for_agent: false),
        Helpers::CustomFieldValidatorHelper.new(id: 42, account_id: 1, name: 'phone_2', label: 'phone_2', label_in_portal: 'phone_2', field_type: 'custom_phone_number', position: 42, required_for_agent: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, contact_form_id: 1),
        Helpers::CustomFieldValidatorHelper.new(id: 43, account_id: 1, name: 'url_1', label: 'url_1', field_type: 'custom_url', position: 43, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, company_form_id: 1, required_for_agent: false),
        Helpers::CustomFieldValidatorHelper.new(id: 44, account_id: 1, name: 'url_2', label: 'url_2', label_in_portal: 'url_2', field_type: 'custom_url', position: 44, required_for_agent: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, created_at: '2015-08-10 09:24:39', updated_at: '2015-08-11 05:40:01', field_options: {}, contact_form_id: 1),
Helpers::CustomFieldValidatorHelper.new(id: 28, account_id: 1, name: 'date_1', label: 'date', label_in_portal: 'date', description: '', active: true, field_type: 'custom_date', position: 29, required: false, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 1, created_at: '2015-08-10 09:19:26', updated_at: '2015-08-11 05:40:01', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil)
      ]
    end

    def required_choices_validatable_custom_fields
      choices_validatable_custom_fields.each { |x| x.required = true }
    end

    def required_data_type_validatable_custom_fields
      data_type_validatable_custom_fields.each { |x| x.required = true }
    end

    def required_closure_choices_validatable_custom_fields
      choices_validatable_custom_fields.each { |x| x.required_for_closure = true }
    end

    def required_closure_data_type_validatable_custom_fields
      data_type_validatable_custom_fields.each { |x| x.required_for_closure = true }
    end

    def dropdown_choices_by_field_name
      { dropdown2_1: %w(first11 second22 third33 four44), dropdown1_1: ['1st', '2nd'], dropdown_3: ['first', 'second'], dropdown_4: ['third', 'fourth'] }
    end

    def nested_fields_choices_by_name=(custom_nested_choices)
      @@nested_choices = NESTED_CHOICES.merge(custom_nested_choices)
    end

    def nested_fields_choices_by_name
      @@nested_choices
    end
  end
end
