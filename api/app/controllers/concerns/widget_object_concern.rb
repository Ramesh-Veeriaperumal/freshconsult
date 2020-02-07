class WidgetObjectConcern
  extend ActiveSupport::Concern
  include Dashboard::Custom::CustomDashboardConstants
  include Admin::AdvancedTicketing::FieldServiceManagement::Constant

  attr_accessor :name, :type, :grid_config, :refresh_interval, :config_data

  def initialize(widget_name, position, type, options)
    @name = widget_name
    @type = type
    @grid_config = widget_grid_config(position)
    @refresh_interval = WIDGET_MODULES_BY_TOKEN[type].constantize::CACHE_EXPIRY
    @config_data = build_widget_configuration(type, options)
  end

  def widget_grid_config(position)
    if @type == WIDGET_MODULE_TOKEN_BY_NAME[SCORE_CARD]
      { x: position[:x], y: position[:y], width: SCORECARD_DIMENSIONS[:width], height: SCORECARD_DIMENSIONS[:height] }
    else
      { x: position[:x], y: position[:y], height: TREND_DIMENSIONS[:height], width: TREND_DIMENSIONS[:width] }
    end
  end

  def build_widget_configuration(type, options)
    options = options.presence
    options.slice(*"Dashboard::Custom::CustomDashboardConstants::#{WIDGET_MODULES_BY_NAME[type].upcase}_ATTRIBUTES".constantize) if options
  end

  def construct_widget_hash(req_type)
    {
      name: name,
      refresh_interval: refresh_interval
    }.merge(if req_type == :db && config_data && (((FSM_TICKET_FILTERS.include? config_data[:ticket_filter_id]) && Account.current.fsm_custom_to_default_filter_enabled?) ||
             (config_data[:ticket_filter_id] == 'unassigned_service_tasks'))
              { widget_type: type, config_data: config_data }.merge(grid_config.symbolize_keys)
            elsif req_type == :db && config_data
              { widget_type: type, grid_config: grid_config }.merge(config_data.symbolize_keys)
            elsif req_type == :db
              { widget_type: type, grid_config: grid_config }
            else
              { type: type, config_data: config_data }.merge(grid_config.symbolize_keys)
            end)
  end
end
