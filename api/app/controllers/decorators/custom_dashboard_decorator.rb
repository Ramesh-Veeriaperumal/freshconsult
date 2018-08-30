class CustomDashboardDecorator < ApiDecorator
  def initialize(record, options)
    super(record)
  end

  def to_list_hash
    {
      id: record.id,
      name: record.name,
      type: record.access_type,
      group_ids: record.group_accesses.map(&:group_id).presence
    }
  end

  def to_detail_hash
    detail_hash = {
      id: record.id,
      name: record.name,
      widgets: dashboard_widgets,
      last_modified_since: record.updated_at.to_i
    }.merge!(dashboard_access_details)
    detail_hash = add_announcements(detail_hash)
    detail_hash
  end

  def dashboard_widgets
    widget_list = []
    record.widgets.each do |widget|
      widget_list << construct_widget_hash(widget)
    end
    widget_list
  end

  def construct_widget_hash(widget)
    ticket_filter_id = widget.ticket_filter_id
    {
      id: widget.id,
      type: widget.widget_type,
      name: widget.name,
      config_data: widget.config_data.merge(ticket_filter_id.nil? ? {} : { ticket_filter_id: ticket_filter_id }),
      refresh_interval: widget.refresh_interval,
      active: widget.active
    }.merge!(widget.grid_config.symbolize_keys)
  end

  def add_announcements(detail_hash)
    announcement = record.announcements.active.first
    detail_hash[:announcements] = [announcement.as_json['dashboard_announcement']] if announcement
    detail_hash
  end

  def dashboard_access_details
    access_hash = { type: record.access_type }
    access_hash[:group_ids] = record.group_accesses.map(&:group_id).presence
    access_hash
  end
end
