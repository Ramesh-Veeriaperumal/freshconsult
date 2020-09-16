class WidgetObject
  include Dashboard::Custom::CustomDashboardConstants

  CONFIG_OPTION_DEFAULTS = {
    ticket_filter_id: 'unresolved',
    threshold_min: 100,
    threshold_max: 150,
    representation: 0,
    categorised_by: 4,
    group_ids: [1],
    product_id: 1,
    date_range: 2,
    metric: 2,
    metric_type: 1
  }.freeze

  attr_accessor :name, :type, :grid_config, :refresh_interval, :config_data

  def initialize(widget_name, type, options)
    @name = widget_name
    @type = type
    @grid_config = widget_grid_config
    @refresh_interval = WIDGET_MODULES_BY_TOKEN[type].constantize::CACHE_EXPIRY
    @config_data = build_widget_configuration(type, options, options && options[:source])
  end

  def widget_grid_config
    { x: 0, y: 0, height: 2, width: 2 }
  end

  def build_widget_configuration(type, options, source = nil)
    options = options.presence || CONFIG_OPTION_DEFAULTS.dup
    new_options = options.slice(*"Dashboard::Custom::CustomDashboardConstants::#{WIDGET_MODULES_BY_NAME[type].upcase}_ATTRIBUTES".constantize)
    new_options[:source] = source if source
    new_options
  end

  def construct_widget_hash(req_type)
    {
      name: name,
      refresh_interval: refresh_interval
    }.merge(req_type == :db ? { widget_type: type, grid_config: grid_config }.merge(config_data.symbolize_keys) : { type: type, config_data: config_data }.merge(grid_config.symbolize_keys))
  end
end
