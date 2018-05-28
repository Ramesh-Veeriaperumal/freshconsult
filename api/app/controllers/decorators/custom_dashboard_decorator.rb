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
    {
      id: record.id,
      name: record.name,
      widgets: dashboard_widgets
    }.merge!(dashboard_access_details)
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

  def dashboard_access_details
    access_hash = { type: record.access_type }
    access_hash[:group_ids] = record.group_accesses.map(&:group_id).presence
    access_hash
  end
end
