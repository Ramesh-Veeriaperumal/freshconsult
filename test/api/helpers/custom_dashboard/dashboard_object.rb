class DashboardObject
  include ::Dashboard::Custom::CustomDashboardConstants

  attr_reader :name, :accessible_attributes, :widgets, :db_record
  def initialize(access_type = DASHBOARD_ACCESS_TYPE[:all], group_ids = nil, widgets = [])
    @name = generate_random_name
    @accessible_attributes = build_accessible_attributes(access_type, group_ids)
    @widgets = widgets
    @db_record = nil
  end

  def generate_random_name(length = nil)
    length ||= rand(1..10)
    charset = Array('A..Z') + Array('a'..'z')
    Array.new(length) { charset.sample }.join
  end

  def build_accessible_attributes(access_type, group_ids = nil)
    group_ids = !group_ids.is_a?(Array) && !group_ids.nil? ? [group_ids] : group_ids
    { type: access_type, group_ids: group_ids }
  end

  def set_db_record(record)
    @db_record = record
  end

  def add_widget(type, options = {})
    @widgets << WidgetObject.new(generate_random_name, type, options)
  end

  def get_dashboard_index_payload
    { name: name }.merge!(accessible_attributes)
  end

  def get_dashboard_payload(type = :rest)
    widget_items = dashboard_widgets(widgets, type)
    { name: name }.merge(type == :db ? { widgets_attributes: widget_items, accessible_attributes: sanitize_accessible_attributes(accessible_attributes) } : { widgets: widget_items }.merge(accessible_attributes))
  end

  def sanitize_accessible_attributes(accessible_attributes)
    { access_type: accessible_attributes[:type], group_ids: accessible_attributes[:group_ids] }
  end

  def dashboard_widgets(widgets, req_type)
    widget_list = []
    widgets.each do |widget|
      widget_list << widget.construct_widget_hash(req_type)
    end
    widget_list
  end
end
