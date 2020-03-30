module VaRulesTesthelper
  FIELD_TO_TYPE_MAPPING = {
    subject: :text,
    description: :text,
    cf_paragraph: :text,
    cf_text: :text,
    subject_or_description: :text_array,
    tag_names: :text_array,
    from_email: :email,
    to_email: :email,
    ticket_cc: :email,
    ticket_type: :object_id,
    product_id: :object_id,
    group_id: :object_id,
    responder_id: :object_id,
    internal_group_id: :object_id,
    internal_agent_id: :object_id,
    cf_checkbox: :checkbox,
    cf_number: :number,
    status: :choice_list,
    priority: :choice_list,
    source: :choice_list,
    cf_decimal: :decimal,
    cf_date: :date,
    cf_date_time: :date_time,
    nested_field: :nested_field
  }.freeze

  ACTIONS_FIELD_TO_TYPE_MAPPING = {
    priority: :choice_list,
    ticket_type: :object_id,
    status: :choice_list,
    responder_id: :object_id,
    group_id: :object_id,
    internal_agent_id: :object_id,
    product_id: :object_id,
    internal_group_id: :object_id,
    add_a_cc: :email,
    add_tag: :object_id_array
  }.freeze

  EVENTS_FIELD_TO_TYPE_MAPPING = {
    priority: :choice_list,
    ticket_type: :object_id,
    status: :choice_list,
    responder_id: :object_id,
    group_id: :object_id,
    note_type: :note_type
  }.freeze

  TYPE_TO_OPERATOR_MAPPING = {
    text: %i[is is_not contains does_not_contain starts_with ends_with
             is_any_of is_none_of],
    text_array: %i[is is_not contains does_not_contain starts_with ends_with is_any_of is_none_of],
    email: %i[is is_not contains does_not_contain is_any_of is_none_of],
    object_id: %i[in not_in],
    object_id_array: %i[in not_in],
    checkbox: %i[selected not_selected],
    number: %i[is is_not greater_than less_than is_any_of is_none_of],
    decimal: %i[is is_not greater_than less_than],
    date: %i[is is_not greater_than less_than],
    date_time: %i[is is_not greater_than less_than],
    nested_field: %i[is is_not is_any_of is_none_of],
    choice_list: %i[in not_in]
  }.freeze

  CASE_SENSITIVE_TYPES = %i[text paragraph text_array].freeze
  ARRAY_VALUE_OPERATORS = %i[contains does_not_contain starts_with ends_with in not_in is_any_of is_none_of].freeze
  ARRAY_VALUE_ACTIONS = %i[add_tag].freeze

  FIELD_TO_TYPE_MAPPING_CONTACT = {
    email: :email,
    name: :text,
    job_title: :text,
    segments: :object_id_array,
    time_zone: :choice_list,
    language: :choice_list,
    test_custom_text: :text,
    test_custom_paragraph: :text,
    test_custom_checkbox: :checkbox,
    test_custom_number: :number
  }.freeze

  FIELD_TO_TYPE_MAPPING_COMPANY = {
    name: :choice_list,
    domains: :choice_list,
    segments: :object_id_array,
    health_score: :choice_list,
    account_tier: :choice_list,
    industry: :choice_list,
    renewal_date: :date,
    test_custom_text: :text,
    test_custom_paragraph: :text,
    test_custom_checkbox: :checkbox,
    test_custom_number: :number
  }.freeze

  EVALUATE_ON_MAPPING = {
    requester: :contact,
    company: :company,
    ticket: :ticket
  }.freeze

  def generate_mock_value(operator_type, field_name, multiple_values = false)
    case operator_type
    when :email
      Faker::Internet.email
    when :text
      Faker::Lorem.characters(10)
    when :text_array
      multiple_values ? [Faker::Lorem.characters(20), Faker::Lorem.characters(20)] : Faker::Lorem.characters(20)
    when :object_id
      case field_name
      when :ticket_type
        'Incident'
      when :product_id
        Account.current.products.first.id
      when :internal_agent_id
        group = Account.current.ticket_statuses.visible.where(is_default: false).first.status_groups.first.group
        group.agents.first.id
      when :internal_group_id
        group = Account.current.ticket_statuses.visible.where(is_default: false).first.status_groups.first.group.id
      when :group_id
        multiple_values ? Account.current.groups.map(&:id) : Account.current.groups.first.id
      when :responder_id
        Account.current.technicians.first.id
      end
    when :object_id_array
      if field_name == :segments
        Account.current.contact_filters.first.id
      elsif field_name == :add_tag
        [Account.current.tags.first.id.to_s]
      end
    when :checkbox
      nil
    when :date
      Time.zone.now.strftime('%Y-%m-%d')
    when :date_time
      Time.zone.now.iso8601
    when :number
      1
    when :decimal
      1.0
    when :choice_list
      if field_name == :status
        Account.current.ticket_statuses.first.status_id.to_i
      elsif field_name == :time_zone
        'American Samoa'
      elsif field_name == :language
        'ar'
      elsif field_name == :name
        Account.current.companies.pluck(:name).first
      elsif [:domains].include?(field_name)
        Faker::Lorem.characters(10)
      else
        1
      end
    when :note_type
      'public'
    end
  end

  def current_account
    @current_account ||= Account.current
  end

  def transform_name(name)
    name.to_s.starts_with?('cf_') ? "#{name}_#{current_account.id}" : name
  end

  def transform_name_for_search(name)
    acc_id = current_account.id.to_s
    name.to_s.starts_with?('cf_') && name.to_s.ends_with?("_#{acc_id}") ?
      name.to_s[0..(name.length - acc_id.length - 2)] : name
  end

  def transform_value(value, transform_type)
    case transform_type.to_sym
    when :array
      return [value] unless value.is_a?(Array)
    end
    value
  end

  def get_condition_field_type(field_name, resource_type)
    case resource_type
    when :contact
      FIELD_TO_TYPE_MAPPING_CONTACT[field_name]
    when :company
      FIELD_TO_TYPE_MAPPING_COMPANY[field_name]
    else
      FIELD_TO_TYPE_MAPPING[field_name]
    end
  end
end
