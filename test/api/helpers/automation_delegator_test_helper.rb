module AutomationDelegatorTestHelper
  include Admin::AutomationConstants

  CUSTOM_FIELDS_TYPES = %w[text paragraph checkbox number].freeze

  # object_id type fields
  DEFAULT_TICKET_FIELD_VALUES = [
    { field_name: 'status', value: [2, 3], field_type: :object_id }.freeze,
    { field_name: 'responder_id', value: (Account.first.try(:technicians).present? ? Account.first.technicians.map(&:id) : [""]), field_type: :object_id }.freeze
  ].freeze

  DEFAULT_CONTACT_FIELD_VALUES = [
    { field_name: 'language', value: %w[ar zh-CN], field_type: :object_id }.freeze,
    { field_name: 'time_zone', value: %w[American Samoa Alaska], field_type: :object_id }.freeze
  ].freeze

  DEFAULT_COMPANY_FIELD_VALUES = [
    { field_name: 'account_tier', value: %w[Basic Premium], field_type: :object_id }.freeze,
    { field_name: 'health_score', value: ['At risk', 'Doing okay'], field_type: :choicelist }.freeze
  ].freeze

  def construct_custom_field_params(field_type, resource_type)
    properties = custom_field_properties(field_type, resource_type)
    { name: 'delegator test', active: true,
      conditions: [{ name: 'condition set 1', match_type: 'any', properties: properties }],
      actions: [{ field_name: 'status', value: 2 }] }
  end

  def construct_customer_params(field_type, resource_type)
    properties = custom_field_customer_properties(field_type, resource_type)
    { name: 'delegator test', active: true,
      conditions: [{ name: 'condition set 1', match_type: 'any', properties: properties }],
      actions: [{ field_name: 'status', value: 2 }] }
  end

  def construct_delegator_params(field_name, resource_type)
    field_hash = case resource_type.try(:to_sym)
                 when :contact
                   DEFAULT_CONTACT_FIELD_VALUES.select { |field| field[:field_name].to_sym == field_name.to_sym }.first
                 when :company
                   DEFAULT_COMPANY_FIELD_VALUES.select { |field| field[:field_name].to_sym == field_name.to_sym }.first
                 else
                   DEFAULT_TICKET_FIELD_VALUES.select { |field| field[:field_name].to_sym == field_name.to_sym }.first
                 end
    operator = FIELD_TYPE[field_hash[:field_type]][0].to_s
    value = ARRAY_VALUE_EXPECTING_OPERATOR.include?(operator.to_sym) ? field_hash[:value] : field_hash[:value][0]
    { name: 'delegator test', active: true,
      conditions: [{ name: 'condition set 1', match_type: 'any',
                     properties: [{ resource_type: resource_type, field_name: field_hash[:field_name],
                                   operator: operator, value: value }] }],
      actions: [{ field_name: 'status', value: 2 }] }
  end

  def custom_field_properties(field_type, resource_type)
    case field_type.to_sym
    when :nested_field
      [{ resource_type: 'ticket', field_name: 'test_custom_country',
         operator: 'is', value: 'USA', nested_fields: {
              level2: { field_name: 'test_custom_state', operator: 'is', value: 'California' },
              level3: { field_name: 'test_custom_city', operator: 'is', value: 'Los Angeles' } } }]
    when :custom_dropdown
      [{ resource_type: resource_type, field_name: 'test_custom_dropdown',
         operator: 'is', value: 'Pursuit of Happiness' }]
    when :custom_checkbox
      [{ resource_type: resource_type, field_name: 'cf_custom_checkbox', operator: 'selected' }]
    when :custom_text
      [{ resource_type: resource_type, field_name: 'cf_custom_text', operator: 'is', value: 'test value' }]
    when :custom_paragraph
      [{ resource_type: resource_type, field_name: 'cf_custom_paragraph', operator: 'is', value: 'test values' }]
    when :custom_number
      [{ resource_type: resource_type, field_name: 'cf_custom_number', operator: 'is', value: 8 }]
    when :custom_decimal
      [{ resource_type: resource_type, field_name: 'cf_custom_decimal', operator: 'is', value: 6.6 }]
    when :custom_date
      [{ resource_type: resource_type, field_name: 'cf_custom_date', operator: 'is', value: '2019-08-24' }]
    end
  end

  def custom_field_customer_properties(field_type, resource_type)
    case field_type
    when :checkbox
      [{ resource_type: resource_type, field_name: "custom_#{field_type}", operator: 'selected' }]
    when :text
      [{ resource_type: resource_type, field_name: "custom_#{field_type}", operator: 'is', value: 'test value' }]
    when :number
      [{ resource_type: resource_type, field_name: "custom_#{field_type}", operator: 'is', value: 8 }]
    when :paragraph
      [{ resource_type: resource_type, field_name: "custom_#{field_type}", operator: 'is', value: 'test value' }]
    end
  end

  def create_ticket_custom_field(field_type)
    case field_type
    when :nested_fields
      create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
    when :custom_dropdown
      create_custom_field_dropdown
    when :custom_checkbox
      create_custom_field("cf_#{field_type}", 'checkbox')
    when :custom_text
      create_custom_field("cf_#{field_type}", 'text')
    when :custom_paragraph
      create_custom_field("cf_#{field_type}", 'paragraph')
    when :custom_number
      create_custom_field("cf_#{field_type}", 'number')
    when :custom_decimal
      create_custom_field("cf_#{field_type}", 'decimal')
    when :custom_date
      create_custom_field("cf_#{field_type}", 'date')
    end
  end

  def get_custom_contact_fields
    CUSTOM_FIELDS_TYPES.each do |field_type|
      cf_params = cf_params(type: field_type, field_type: "custom_#{field_type}",
                            label: "test_custom_#{field_type}", editable_in_signup: 'true')
      create_custom_contact_field(cf_params)
    end
  end

  def get_custom_company_fields
    CUSTOM_FIELDS_TYPES.each do |field_type|
      cf_params = company_params({ type: field_type, field_type: "custom_#{field_type}",
                                   label: "test_custom_#{field_type}" })
      create_custom_company_field(cf_params)
    end
  end

  def create_tags_data(account)
    count = 1
    3.times do
      account.tags.create(name: "test#{count}")
      count += 1
    end
  end

  def create_products(account)
    count = 1
    3.times do
      account.products.create(name: "test#{count}", description: "test_description#{count}")
      count += 1
    end
  end

  def get_all_custom_fields
    @account = Account.current || Account.first.make_current
    %w[checkbox date text paragraph number decimal].each do |dom|
      create_custom_field("cf_#{dom}", dom)
    end
    @account = nil
  end

  def get_a_dropdown_custom_field
    @account = Account.current || Account.first.make_current
    create_custom_field_dropdown
    @account = nil
  end

  def get_a_nested_custom_field
    @account = Account.current || Account.first.make_current
    create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
    @account = nil
  end

  def automation_delegator_class
    'Admin::AutomationRules::AutomationDelegator'.constantize
  end
end