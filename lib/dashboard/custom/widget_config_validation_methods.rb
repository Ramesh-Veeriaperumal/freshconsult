module Dashboard::Custom::WidgetConfigValidationMethods
  NUMBER = 0
  PERCENTAGE = 1

  ALL_GROUPS = 0
  ALL_PRODUCTS = 0
  PRODUCT_NONE = -1
  ALL_TYPES = 0
  ALL_QUEUES = 0

  #  :default_requester and :default_company removed considering the huge count
  VALID_GROUP_BY_FIELDS = [:default_source, :default_internal_group, :default_internal_agent,
                           :default_status, :default_priority, :default_group, :default_agent, :default_product, :nested_field,
                           :custom_dropdown, :default_ticket_type].freeze

  DATE_FIELDS_MAPPING = {
    1 => 'Today',
    2 => 'This week',
    3 => 'This month',
    4 => 'Last 7 days',
    5 => 'Last 30 days'
  }.freeze

  def validate_ticket_filter_id(ticket_filter_id)
    if ticket_filter_id.to_i.zero?
      Helpdesk::Filters::CustomTicketFilter::DEFAULT_FILTERS.key?(ticket_filter_id) || ::Admin::AdvancedTicketing::FieldServiceManagement::Constant::FSM_TICKET_FILTERS.include?(ticket_filter_id)
    else
      ticket_filter = Account.current.ticket_filters.find_by_id(ticket_filter_id.to_i)
      ticket_filter && !ticket_filter.accessible.only_me?
    end
  end

  def validate_categorised_by(group_by)
    ticket_field = Account.current.ticket_fields_from_cache.select { |tf| tf.id == group_by.to_i }[0]
    ticket_field ? VALID_GROUP_BY_FIELDS.include?(ticket_field.field_type.to_sym) : false
  end

  def validate_representation(representation)
    representation.to_i == NUMBER || representation.to_i == PERCENTAGE
  end

  def validate_time_range(time_range)
    time_range.present? ? (Dashboard::SurveyWidget::TIME_PERIODS.keys | Dashboard::SurveyWidget::TIME_RANGE.keys).include?(time_range.to_i) : false
  end

  def validate_group_id(group_id)
    return true if group_id.to_i.zero? # Group id can be zero if the filter is all groups
    if User.current.agent.all_ticket_permission
      groups = Account.current.groups_from_cache.map(&:id)
      return groups.include?(group_id.to_i)
    else
      User.current.agent_groups.pluck(:group_id).include?(group_id.to_i)
    end
  end

  def validate_group_ids(group_ids)
    return true if group_ids.blank?
    group_ids = group_ids.map(&:to_i)
    if User.current.agent.all_ticket_permission
      group_ids.include?(ALL_GROUPS) || (group_ids - Account.current.groups_from_cache.map(&:id)).empty?
    else
      (group_ids - User.current.agent_groups.pluck(:group_id)).empty?
    end
  end

  def validate_product_id(product_id)
    product_id.blank? || product_id.to_i == ALL_PRODUCTS || product_id.to_i == PRODUCT_NONE || (Account.current.multi_product_enabled? && Account.current.products_from_cache.map(&:id).include?(product_id.to_i))
  end

  def validate_date_range(date_range)
    DATE_FIELDS_MAPPING[date_range.to_i]
  end

  def validate_ticket_type(ticket_type)
    ticket_type.blank? || ticket_type.to_i == ALL_TYPES || Account.current.ticket_types_from_cache.map(&:id).include?(ticket_type.to_i)
  end
end
