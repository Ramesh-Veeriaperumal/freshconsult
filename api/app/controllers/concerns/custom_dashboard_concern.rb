module CustomDashboardConcern
  extend ActiveSupport::Concern

  include ::Dashboard::Custom::CustomDashboardConstants
  include Dashboard::Custom::DashboardDecorationMethods
  include Helpdesk::IrisNotifications

  def sanitize_params
    ParamsHelper.assign_and_clean_params({ widgets: :widgets_attributes, type: :access_type }, cname_params)
    build_accessible_attributes
    sanitize_widgets_attributes if cname_params.key?(:widgets_attributes)
  end

  def build_accessible_attributes
    accessible_attributes = cname_params.extract!(:access_type, :group_ids).reject { |key, value| value.nil? }
    accessible_attributes[:access_type] = 2 if accessible_attributes[:group_ids].present? && !accessible_attributes[:access_type].present?
    cname_params[:accessible_attributes] = accessible_attributes if accessible_attributes.present?
  end

  def sanitize_widgets_attributes
    cname_params[:widgets_attributes].each do |widget|
      widget[:config_data].each  do |widget_attr, value|
        widget[widget_attr] = value
      end
      widget.delete(:config_data)
      widget[:_destroy] = widget.delete(:deleted) if widget[:deleted] == true
      widget[:widget_type] = widget.delete(:type) if widget[:type]
    end
  end

  def build_delegator_hash
    cname_params.select { |key, value| [:name, :widgets_attributes, :accessible_attributes].include?(key.to_sym) }
  end

  def before_build_object
    validate_req_params
  end

  def build_object
    @item = scoper.new(cname_params)
  end

  def validate_req_params(record = nil, delegator_params = build_delegator_hash)
    validate_body_params && validate_delegator(record, delegator_params)
  end

  def load_objects
    dashboard_object_list = load_objects_from_redis
    if dashboard_object_list.empty?
      dashboard_object_list = load_objects_from_db
    end
    @items = get_accessible_dashboards(dashboard_object_list)
  end

  def load_objects_from_redis
    dashboard_list = parse_dashboards_from_redis(multi_get_all_redis_hash(dashboard_index_redis_key))
    dashboard_list.map(&:symbolize_keys!)
  end

  def parse_dashboards_from_redis(dashboard_hash)
    dashboard_list = []
    dashboard_hash.each do |id, dashboard_object|
      dashboard_list << JSON.parse(dashboard_object)
    end
    dashboard_list
  end

  def load_objects_from_db
    items = scoper.includes(accessible: [:group_accesses])
    dashboard_list = decorate_dashboard_list(items)
    load_dashboard_index_in_redis(dashboard_list)
    dashboard_list
  end

  # Loads all account dashboards in redis with accesses
  def load_dashboard_index_in_redis(dashboard_list)
    dashboard_by_id = dashboard_list.map { |dashboard| [dashboard[:id], dashboard.to_json] }.to_h
    multi_set_redis_hash(dashboard_index_redis_key, dashboard_by_id.flatten) if dashboard_by_id.present? # hmset doesn't accept empty args
  end

  def get_accessible_dashboards(dashboard_object_list)
    unless dashboard_admin?
      user_group_ids = current_user.groups.pluck(:id)
      dashboard_object_list.select! { |item| item[:type] == DASHBOARD_ACCESS_TYPE[:all] || (item[:group_ids].present? && item[:group_ids].any? { |x| user_group_ids.include?(x) }) }
    end
    dashboard_object_list
  end

  def assign_dashboard_attributes
    @item.assign_attributes(cname_params)
  end

  def load_dashboard_from_cache
    @item = MemcacheKeys.fetch_unless_empty(dashboard_cache_key(params[:id])) do
      item = scoper.includes(:widgets, accessible: [:group_accesses]).find_by_id(params[:id])
      decorate_dashboard(item).to_detail_hash unless item.nil?
    end
  end

  def load_object
    @item = (action == :update) ? scoper.includes(:widgets).find_by_id(params[:id]) : scoper.find_by_id(params[:id])
    log_and_render_404 unless @item
  end

  def dashboard_accessible?
    return true if dashboard_accessible_type == DASHBOARD_ACCESS_TYPE[:all] || current_user.agent.all_ticket_permission && dashboard_admin?

    user_group_ids = current_user.agent_groups.pluck(:group_id)
    @item[:group_ids].present? && @item[:group_ids].any? { |x| user_group_ids.include?(x) }
  end

  def dashboard_admin?
    current_user.privilege?(:manage_dashboard)
  end

  def build_announcement
    @dashboard_announcement = @item.announcements.build(user_id: User.current.id, announcement_text: params[:announcement_text], active: true)
  end

  def load_announcement
    @dashboard_announcement = @item.announcements.find_by_id(params[:announcement_id])
    log_and_render_404 unless @dashboard_announcement
  end

  def announcement_for_dashboard
    announcement_item = @item.announcements.active.first
    announcement_item ? announcement_item.as_json['dashboard_announcement'] : {}
  end

  def fetch_announcements_with_count(page)
    options = page ? { page: page } : {}
    iris_response = fetch_data_from_service(announcements_collect_path(@item.id), options)
    announcement_counts = iris_response['announcements'].map { |an| [an['announcement_id'], an['counts']['read_by']] }.to_h
    dashboard_announcements = @item.announcements.where(id: announcement_counts.keys)
    [dashboard_announcements.as_json.map { |an| an['dashboard_announcement'].merge(count: announcement_counts[an['dashboard_announcement']['id'].to_s]) }, { next_page: iris_response['next_page'] }]
  end

  def fetch_announcement_with_viewers
    iris_response = fetch_data_from_service(announcement_viewers_path(@item.id, @dashboard_announcement.id), {})
    viewers = iris_response.map { |r| r['identifier'] }
    @dashboard_announcement.as_json['dashboard_announcement'].merge(viewers: viewers)
  end

  def omni_preview_accesible?(source)
    case source
    when SOURCES[:freshcaller]
      User.current.freshcaller_agent_enabled?
    when SOURCES[:freshchat]
      User.current.freshchat_agent_enabled?
    else
      false
    end
  end

  def valid_omni_widget_module?(params)
    type = params['type']
    module_klass = WIDGET_MODULES_BY_TOKEN[type.to_i].constantize
    module_klass.valid_config?(params)
  end

  def dashboard_accessible_type
    @item.is_a?(Hash) ? @item[:type] : @item.accessible[:access_type]
  end
end
