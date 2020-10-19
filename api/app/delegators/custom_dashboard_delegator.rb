class CustomDashboardDelegator < BaseDelegator

  include Dashboard::Custom::CustomDashboardConstants

  validate :dashboard_creation_limit, on: :create
  validate :validate_access_type, if: -> { @accessible_attributes && @accessible_attributes.key?(:access_type) }
  validate :validate_accessible_groups, if: -> { @accessible_attributes && @accessible_attributes.key?(:group_ids) }
  validate :validate_widgets, if: -> { @widgets_attributes }
  validate :validate_announcement, if: -> { @announcement_text }
  
  def initialize(record, options)
    options.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
    @dashboards = Account.current.dashboards
    initialise_widget_counts_to_zero
    if record.present?
      @dashboard = record
      widgets = record.widgets
      @widget_by_id = Hash[widgets.map { |w| [w[:id], w] }]
      count_existing_widgets(widgets)
    end
    @dashboard_limits = Account.current.account_additional_settings.custom_dashboard_limits
    super(record, options)
  end

  def count_existing_widgets(widgets)
    widgets.each do |widget|
      case widget.source
      when SOURCES[:freshcaller], SOURCES[:freshchat]
        @widget_count[widget.source + '_' + WIDGET_MODULES_BY_SHORT_NAME[widget.widget_type]] += 1
      else
        @widget_count[WIDGET_MODULES_BY_NAME[widget.widget_type]] += 1
      end
    end
  end

  def initialise_widget_counts_to_zero
    @widget_count = (WIDGET_MODULE_TOKEN_BY_NAME.keys - OMNI_WIDGETS).inject({}) { |h, k| h.merge(k => 0) }.merge(OMNI_WIDGET_INITIAL_LIMIT)
  end

  def dashboard_creation_limit
    unless @dashboards.length < @dashboard_limits[:dashboard]
      errors[:dashboard] << :dashboard_limit_exceeded
    end
  end

  def validate_access_type
    if !DASHBOARD_ACCESS_TYPE.values.include?(@accessible_attributes[:access_type]) || all_access_dashboard?(@accessible_attributes[:access_type]) && !User.current.agent.all_ticket_permission
      errors[:type] << 'is invalid'
    end
  end

  def validate_accessible_groups
    group_ids = @accessible_attributes[:group_ids]
    if @accessible_attributes[:access_type] != DASHBOARD_ACCESS_TYPE[:groups]
      errors[:group_ids] << 'incompatible_field'
      return
    else
      valid_groups = fetch_accessible_groups
      errors[:group_ids] << 'inaccessible_value' unless group_ids.all? { |group_id| valid_groups.include?(group_id) }
    end
  end

  def validate_widgets
    errors[:widgets] << 'is invalid' unless @widgets_attributes.all? { |w| valid_widget?(w) }
    validate_widgets_limit
  end

  def validate_widgets_limit
    @widgets_attributes.each { |w| update_widget_count(w) }
    errors[:widgets] = :dashboard_limit_exceeded unless @widget_count.all? { |k, v| @dashboard_limits[:widgets][k.to_sym] >= v } && @dashboard_limits[:total_widgets] >= @widget_count.values.sum
  end

  def update_widget_count(widget)
    return unless widget_created_or_destoryed?(widget) # Rejecting widget updates from counting.
    widget_type = WIDGET_MODULES_BY_NAME[widget[:widget_type] || @widget_by_id[widget[:id]].widget_type]
    source = widget[:source] || (widget[:id] && @widget_by_id[widget[:id]].source)
    case source
    when SOURCES[:freshcaller], SOURCES[:freshchat]
      omni_widget_type = source + '_' + WIDGET_MODULES_BY_SHORT_NAME[widget[:widget_type] || @widget_by_id[widget[:id]].widget_type]
      @widget_count[omni_widget_type] += widget[:_destroy].present? ? -1 : 1
    else
      @widget_count[widget_type] += widget[:_destroy].present? ? -1 : 1 unless OMNI_WIDGETS.include?(widget_type)
    end
  end

  def widget_created_or_destoryed?(widget)
    widget[:id].nil? || widget[:_destroy].present?
  end

  def valid_widget_config?(widget, type, new_widget_params = {})
    WIDGET_MODULES_BY_TOKEN[type].constantize.valid_config?(widget) == true && widget_update_allowed_for_current_user?(widget, new_widget_params)
  end

  def valid_widget?(widget)
    widget[:id] ? @widget_by_id.keys.include?(widget['id']) && valid_widget_updates?(widget) : valid_widget_config?(widget, widget['widget_type'])
  end

  def valid_widget_updates?(widget)
    # Check for widget length to be 1: ui updates will send id alone if nothing has been changed.
    return true if widget.length == 1 || widget[:_destroy].present?
    widget_to_be_updated = @widget_by_id[widget[:id]]
    widget_changes = widget_to_be_updated.config_data.merge(ticket_filter_id: widget_to_be_updated.ticket_filter_id).merge(widget)
    valid_widget_config?(widget_changes, widget_to_be_updated['widget_type'], widget)
  end

  def all_access_dashboard?(access_type)
    access_type == DASHBOARD_ACCESS_TYPE[:all]
  end

  def fetch_accessible_groups
    User.current.agent.all_ticket_permission ? Account.current.groups_from_cache.map(&:id) : User.current.agent_groups.pluck(:group_id)
  end

  def validate_announcement
    errors[:announcement] = :announcement_limit_exceeded unless @dashboard.present? && @dashboard.announcements.active.empty?
  end

  def widget_update_allowed_for_current_user?(widget, new_widget_params = {})
    return true unless widget_privilege_check_needed?(new_widget_params)

    case widget[:source] || (widget[:id] && @widget_by_id[widget[:id]].source)
    when SOURCES[:freshcaller]
      freshcaller_agent?
    when SOURCES[:freshchat]
      freshchat_agent?
    else
      true
    end
  end

  private

    def freshcaller_agent?
      return @freshcaller_agent if defined?(@freshcaller_agent)

      @freshcaller_agent ||= User.current.freshcaller_agent_enabled?
    end

    def freshchat_agent?
      return @freshchat_agent if defined?(@freshchat_agent)

      @freshchat_agent ||= User.current.freshchat_agent_enabled?
    end

    def widget_privilege_check_needed?(new_widget_params)
      Account.current.omni_channel_team_dashboard_enabled? && (new_widget_params[:id].blank? || !new_widget_params.except(:x, :y, :id).empty?)
    end
end
