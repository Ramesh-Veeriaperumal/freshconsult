class CustomDashboardDelegator < BaseDelegator

  include Dashboard::Custom::CustomDashboardConstants

  validate :dashboard_creation_limit, on: :create
  validate :validate_access_type, if: -> { @accessible_attributes && @accessible_attributes.key?(:access_type) }
  validate :validate_accessible_groups, if: -> { @accessible_attributes && @accessible_attributes.key?(:group_ids) }
  validate :validate_widgets, if: -> { @widgets_attributes }
  
  def initialize(record, options)
    options.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
    @dashboards = Account.current.dashboards
    initialise_widget_counts_to_zero
    if record.present?
      widgets = record.widgets
      @widget_by_id = Hash[widgets.map { |w| [w[:id], w] }]
      count_existing_widgets(widgets)
    end
    @dashboard_limits = Account.current.account_additional_settings.dashboard_creation_limits
    super(record, options)
  end

  def count_existing_widgets(widgets)
    widgets.each do |widget|
      widget_type = trend_card_widget?(widget) ? REPORT_WIDGET_MODULES_BY_TOKEN[widget.config_data[:metric_type]] : WIDGET_MODULES_BY_NAME[widget.widget_type]
      @widget_count[widget_type] += 1
    end
  end

  def initialise_widget_counts_to_zero
    @widget_count = (WIDGET_MODULE_TOKEN_BY_NAME.keys + REPORT_WIDGET_MODULES_BY_NAME.keys - ['trend_card']).inject({}) { |h, k| h.merge(k => 0) }
  end

  def trend_card_widget?(widget)
    widget.widget_type == WIDGET_MODULE_TOKEN_BY_NAME[:trend_card.to_s]
  end

  def dashboard_creation_limit
    unless @dashboards.length < @dashboard_limits[:dashboard]
      errors[:dashboard] << :dashboard_limit_exceeded
    end
  end

  def validate_access_type
    unless DASHBOARD_ACCESS_TYPE.values.include?(@accessible_attributes[:access_type])
      errors[:type] << 'is invalid'
    end
  end

  def validate_accessible_groups
    group_ids = @accessible_attributes[:group_ids]
    access_type = @accessible_attributes[:access_type]
    valid_groups = Account.current.groups_from_cache.collect(&:id)
    unless access_type == DASHBOARD_ACCESS_TYPE[:groups]
      errors[:group_ids] << 'incompatible_field'
      return
    end
    unless group_ids.all? { |group_id| valid_groups.include?(group_id) }
      errors[:group_ids] << 'inaccessible_value'
    end
  end

  def validate_widgets
    errors[:widgets] << 'is invalid' unless @widgets_attributes.all? { |w| valid_widget?(w) }
    validate_widgets_limit
  end

  def validate_widgets_limit
    @widgets_attributes.each { |w| update_widget_count(w) }
    errors[:widgets] = :dashboard_limit_exceeded unless @widget_count.all? { |k, v| @dashboard_limits[:widgets][k.to_sym] >= v }
  end

  def update_widget_count(widget)
    return unless widget_created_or_destoryed?(widget) # Rejecting widget updates from counting.
    widget_type = WIDGET_MODULES_BY_NAME[widget[:widget_type] || @widget_by_id[widget[:id]].widget_type]
    widget_type = REPORT_WIDGET_MODULES_BY_TOKEN[widget[:metric_type] || @widget_by_id[widget[:id]].config_data[:metric_type]] if widget_type == :trend_card.to_s
    @widget_count[widget_type] += widget[:_destroy].present? ? -1 : 1
  end

  def widget_created_or_destoryed?(widget)
    widget[:id].nil? || widget[:_destroy].present?
  end

  def valid_widget_config?(widget, type)
    WIDGET_MODULES_BY_TOKEN[type].constantize.valid_config?(widget) == true
  end

  def valid_widget?(widget)
    widget[:id] ? @widget_by_id.keys.include?(widget['id']) && valid_widget_updates?(widget) : valid_widget_config?(widget, widget['widget_type'])
  end

  def valid_widget_updates?(widget)
    # Check for widget length to be 1: ui updates will send id alone if nothing has been changed.
    return true if widget.length == 1 || widget[:_destroy].present?
    widget_to_be_updated = @widget_by_id[widget[:id]]
    widget_changes = widget_to_be_updated.config_data.merge(ticket_filter_id: widget_to_be_updated.ticket_filter_id).merge(widget)
    valid_widget_config?(widget_changes, widget_to_be_updated['widget_type'])
  end
end
