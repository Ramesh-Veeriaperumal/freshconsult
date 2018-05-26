module Dashboard::Custom::CustomDashboardConstants
  
  WIDGETS_DATA_FIELDS = %w(type)
  WIDGET_DATA_PREVIEW_FIELDS = %w(type ticket_filter_id)

  ACCESSIBLE_ATTRIBUTES_FIELDS = [accessible_attributes: [:access_type, :group_ids]].freeze

  SCORECARD_ATTRIBUTES = [:ticket_filter_id, :threshold_max, :threshold_min].freeze
  BAR_CHART_ATTRIBUTES = [:ticket_filter_id, :categorised_by, :representation].freeze
  LEADERBOARD_ATTRIBUTES = [:group_id]
  CSAT_ATTRIBUTES = [:group_ids, :time_range]
  FORUM_MODERATION_ATTRIBUTES = []
  TREND_CARD_ATTRIBUTES = [:group_ids, :product_id, :metric, :metric_type, :date_range, :threshold_max, :threshold_min].freeze

  WIDGETS_ATTRIBUTES_FIELDS = [widgets_attributes:
    [:widget_type, :name, :x, :y, :width, :height, :refresh_interval, :config_data] |
      SCORECARD_ATTRIBUTES |
      BAR_CHART_ATTRIBUTES |
      CSAT_ATTRIBUTES |
      LEADERBOARD_ATTRIBUTES |
      TREND_CARD_ATTRIBUTES].freeze

  CREATE_FIELDS = %w(name) | ACCESSIBLE_ATTRIBUTES_FIELDS | WIDGETS_ATTRIBUTES_FIELDS
  UPDATE_FIELDS = %w(name accessible_attributes widgets_attributes)

  SCORECARD_PREVIEW_FIELDS = %w(ticket_filter_id)
  BAR_CHART_PREVIEW_FIELDS = %w(ticket_filter_id categorised_by sort representation view_all)
  LEADERBOARD_PREVIEW_FIELDS = %w(group_id)
  CSAT_PREVIEW_FIELDS = %w(group_ids time_range)
  FORUM_MODERATION_PREVIEW_FIELDS = %w().freeze
  TREND_CARD_PREVIEW_FIELDS = %w(group_ids product_id metric metric_type date_range)
  BAR_CHART_DATA_FIELDS = %w(widget_id)
  VALIDATION_CLASS = 'CustomDashboardValidation'.freeze
  DELEGATOR_CLASS = 'CustomDashboardDelegator'.freeze

  ROOT_KEY = {
    widgets_data: :widgets,
    widget_data_preview: :preview_data,
    index: :dashboards,
    create: :dashboard,
    update: :dashboard,
    show: :dashboard,
    bar_chart_data: :chart_data
  }.freeze

  WIDGET_MODULES = [
    ['scorecard', 0, 'Dashboard::Custom::Scorecard'],
    ['bar_chart', 1, 'Dashboard::Custom::BarChart'],
    ['csat', 2, 'Dashboard::Custom::Csat'],
    ['leaderboard', 3, 'Dashboard::Custom::Leaderboard'],
    ['forum_moderation', 4, 'Dashboard::Custom::ForumModerationWidget'],
    ['trend_card', 5, 'Dashboard::Custom::TrendCard']
  ].freeze

  REPORT_WIDGET_MODULES = [
    ['ticket_trend_card', 1],
    ['time_trend_card', 2],
    ['sla_trend_card', 3]
  ].freeze

  REPORT_WIDGET_MODULES_BY_NAME = Hash[*REPORT_WIDGET_MODULES.map { |i| [i[0], i[1]] }.flatten]
  REPORT_WIDGET_MODULES_BY_TOKEN = Hash[*REPORT_WIDGET_MODULES.map { |i| [i[1], i[0]] }.flatten]
  WIDGET_MODULES_BY_TOKEN = Hash[*WIDGET_MODULES.map { |i| [i[1], i[2]] }.flatten]
  WIDGET_MODULES_BY_NAME = Hash[*WIDGET_MODULES.map { |i| [i[1], i[0]] }.flatten]
  WIDGET_MODULES_BY_KLASS = Hash[*WIDGET_MODULES.map { |i| [i[0], i[2]] }.flatten]
  WIDGET_MODULE_NAMES = WIDGET_MODULES.map(&:first)
  WIDGET_MODULE_TOKEN_BY_NAME = Hash[*WIDGET_MODULES.map { |i| [i[0], i[1]] }.flatten]

  DASHBOARD_ACCESS_TYPE = { all: 0, users: 1, groups: 2 }.freeze

  NUMBER = 0
  PERCENTAGE = 1
end
