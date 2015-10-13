class Helpers::DefaultFieldValidatorHelper
  attr_accessor :id, :account_id, :name, :label, :label_in_portal, :description, :active, :field_type, :position, :required, :visible_in_portal, :editable_in_portal, :required_in_portal, :required_for_closure, :flexifield_def_entry_id, :created_at, :updated_at, :field_options, :default, :level, :parent_id, :prefered_ff_col, :import_id 

  def initialize(params = {})
    params.each { |key, value| instance_variable_set("@#{key}", value) }
  end

  class << self
    def default_field_validations
      {
        status: {custom_inclusion: { in: [2, 3, 4, 5], ignore_string: :allow_string_param }},
        source: {custom_inclusion: { in: [2, 3, 4, 5], ignore_string: :allow_string_param }},
        priority: {custom_inclusion: { in: ApiTicketConstants::PRIORITIES, ignore_string: :allow_string_param }},
        source: {custom_inclusion: { in: ApiTicketConstants::SOURCES, ignore_string: :allow_string_param }},
        type: {custom_inclusion: { in: ['Lead', 'Question', 'Problem', 'Maintenance', 'Breakage'] }},
        group_id: {custom_numericality: {ignore_string: :allow_string_param}},
        responder_id: {custom_numericality: {ignore_string: :allow_string_param}},
        product_id: {custom_numericality: {ignore_string: :allow_string_param}},
        subject: {length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }},
        client_manager: { data_type: { rules: 'Boolean', ignore_string: :allow_string_param }},
        job_title:  { data_type: { rules: String }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }},
        language: { custom_inclusion: { in: ContactConstants::LANGUAGES }},
        tags:  { data_type: { rules: Array }, array: { data_type: { rules: String }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long } }, string_rejection: { excluded_chars: [','] }},
        time_zone: { custom_inclusion: { in: ContactConstants::TIMEZONES }},
        phone: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }},
        mobile: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }},
        address: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }},
        twitter_id: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }},
        email: { format: { with: ApiConstants::EMAIL_VALIDATOR, message: 'not_a_valid_email' }, data_type: { rules: String }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long } },
        description:  { data_type: { rules: String } },
        note: { data_type: { rules: String } },
        domains:  { data_type: { rules: Array }, array: { data_type: { rules: String } }, string_rejection: { excluded_chars: [','] } }
      }
    end

    def required_fields
      [
        Helpers::DefaultFieldValidatorHelper.new(id: 11, account_id: 1, name: 'status', label: 'single', label_in_portal: 'single', description: '', active: true, field_type: 'custom_text', position: 2, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 1, created_at: '2015-08-10 09:19:26', updated_at: '2015-08-11 05:40:01', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 12, account_id: 1, name: 'priority', label: 'check1', label_in_portal: 'check1', description: '', active: true, field_type: 'custom_checkbox', position: 6, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 2, created_at: '2015-08-10 09:19:26', updated_at: '2015-08-10 09:24:39', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 23, account_id: 1, name: 'source', label: 'check2', label_in_portal: 'check2', description: '', active: true, field_type: 'custom_checkbox', position: 4, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 13, created_at: '2015-08-10 09:24:36', updated_at: '2015-08-10 09:24:37', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 16, account_id: 1, name: 'type', label: 'decimal1', label_in_portal: 'decimal1', description: '', active: true, field_type: 'custom_decimal', position: 10, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 6, created_at: '2015-08-10 09:19:28', updated_at: '2015-08-10 09:24:41', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 24, account_id: 1, name: 'group_id', label: 'decimal2', label_in_portal: 'decimal2', description: '', active: true, field_type: 'custom_decimal', position: 5, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 14, created_at: '2015-08-10 09:24:38', updated_at: '2015-08-10 09:24:38', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 18, account_id: 1, name: 'responder_id', label: 'number1', label_in_portal: 'number1', description: '', active: true, field_type: 'custom_number', position: 12, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 8, created_at: '2015-08-10 09:19:29', updated_at: '2015-08-10 09:24:42', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 26, account_id: 1, name: 'subject', label: 'number2', label_in_portal: 'number2', description: '', active: true, field_type: 'custom_number', position: 8, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 16, created_at: '2015-08-10 09:24:40', updated_at: '2015-08-11 05:40:02', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 19, account_id: 1, name: 'client_manager', label: 'multi', label_in_portal: 'multi', description: '', active: true, field_type: 'custom_paragraph', position: 14, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 9, created_at: '2015-08-10 09:19:29', updated_at: '2015-08-10 09:24:42', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 27, account_id: 1, name: 'job_title', label: 'phone', label_in_portal: 'phone', description: '', active: true, field_type: 'custom_phone_number', position: 27, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 1, created_at: '2015-08-10 09:19:26', updated_at: '2015-08-11 05:40:01', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 28, account_id: 1, name: 'language', label: 'url', label_in_portal: 'url', description: '', active: true, field_type: 'custom_url', position: 28, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 1, created_at: '2015-08-10 09:19:26', updated_at: '2015-08-11 05:40:01', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil), 
        Helpers::DefaultFieldValidatorHelper.new(id: 26, account_id: 1, name: 'tags', label: 'number2', label_in_portal: 'number2', description: '', active: true, field_type: 'custom_number', position: 8, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 16, created_at: '2015-08-10 09:24:40', updated_at: '2015-08-11 05:40:02', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 19, account_id: 1, name: 'time_zone', label: 'multi', label_in_portal: 'multi', description: '', active: true, field_type: 'custom_paragraph', position: 14, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 9, created_at: '2015-08-10 09:19:29', updated_at: '2015-08-10 09:24:42', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 27, account_id: 1, name: 'phone', label: 'phone', label_in_portal: 'phone', description: '', active: true, field_type: 'custom_phone_number', position: 27, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 1, created_at: '2015-08-10 09:19:26', updated_at: '2015-08-11 05:40:01', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 28, account_id: 1, name: 'mobile', label: 'url', label_in_portal: 'url', description: '', active: true, field_type: 'custom_url', position: 28, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 1, created_at: '2015-08-10 09:19:26', updated_at: '2015-08-11 05:40:01', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 26, account_id: 1, name: 'address', label: 'number2', label_in_portal: 'number2', description: '', active: true, field_type: 'custom_number', position: 8, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 16, created_at: '2015-08-10 09:24:40', updated_at: '2015-08-11 05:40:02', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 19, account_id: 1, name: 'twitter_id', label: 'multi', label_in_portal: 'multi', description: '', active: true, field_type: 'custom_paragraph', position: 14, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 9, created_at: '2015-08-10 09:19:29', updated_at: '2015-08-10 09:24:42', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 27, account_id: 1, name: 'email', label: 'phone', label_in_portal: 'phone', description: '', active: true, field_type: 'custom_phone_number', position: 27, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 1, created_at: '2015-08-10 09:19:26', updated_at: '2015-08-11 05:40:01', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 28, account_id: 1, name: 'description', label: 'url', label_in_portal: 'url', description: '', active: true, field_type: 'custom_url', position: 28, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 1, created_at: '2015-08-10 09:19:26', updated_at: '2015-08-11 05:40:01', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 26, account_id: 1, name: 'note', label: 'number2', label_in_portal: 'number2', description: '', active: true, field_type: 'custom_number', position: 8, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 16, created_at: '2015-08-10 09:24:40', updated_at: '2015-08-11 05:40:02', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 19, account_id: 1, name: 'domains', label: 'multi', label_in_portal: 'multi', description: '', active: true, field_type: 'custom_paragraph', position: 14, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 9, created_at: '2015-08-10 09:19:29', updated_at: '2015-08-10 09:24:42', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 19, account_id: 1, name: 'company_id', label: 'multi', label_in_portal: 'multi', description: '', active: true, field_type: 'custom_paragraph', position: 14, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 9, created_at: '2015-08-10 09:19:29', updated_at: '2015-08-10 09:24:42', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil),
        Helpers::DefaultFieldValidatorHelper.new(id: 19, account_id: 1, name: 'product_id', label: 'multi', label_in_portal: 'multi', description: '', active: true, field_type: 'custom_paragraph', position: 14, required: true, visible_in_portal: true, editable_in_portal: true, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 9, created_at: '2015-08-10 09:19:29', updated_at: '2015-08-10 09:24:42', field_options: {}, default: false, level: nil, parent_id: nil, prefered_ff_col: nil, import_id: nil)
      ]
    end
  end
end
