module Dashboard::Custom::CustomDashboardConstants

  WIDGETS_DATA_FIELDS = %w(type)
  WIDGET_DATA_PREVIEW_FIELDS = %w(type ticket_filter_id)

  ACCESSIBLE_ATTRIBUTES_FIELDS = [accessible_attributes: [:access_type, :group_ids]].freeze

  SCORECARD_ATTRIBUTES = [:ticket_filter_id, :threshold_max, :threshold_min].freeze
  BAR_CHART_ATTRIBUTES = [:ticket_filter_id, :categorised_by, :representation].freeze
  LEADERBOARD_ATTRIBUTES = [:group_id]
  CSAT_ATTRIBUTES = [:group_ids, :time_range]
  FORUM_MODERATION_ATTRIBUTES = []
  TICKET_TREND_CARD_ATTRIBUTES = [:group_ids, :product_id, :ticket_type, :metric, :date_range, :threshold_max, :threshold_min].freeze
  TIME_TREND_CARD_ATTRIBUTES = [:group_ids, :product_id, :ticket_type, :metric, :date_range, :threshold_max, :threshold_min].freeze
  SLA_TREND_CARD_ATTRIBUTES = [:group_ids, :product_id, :ticket_type, :metric, :date_range, :threshold_max, :threshold_min].freeze
  MS_SCORECARD_ATTRIBUTES = [:view, :threshold_min, :threshold_max].freeze
  MS_BAR_CHART_ATTRIBUTES = [:group_ids, :representation].freeze
  MS_AVAILABILITY_ATTRIBUTES = [:queue_id, :group_ids, :threshold_min, :threshold_max].freeze
  MS_CSAT_ATTRIBUTES = [:group_ids, :date_type].freeze
  MS_TIME_TREND_ATTRIBUTES = [:metric, :queue_id, :time_type, :computation, :date_range, :group_ids, :threshold_min, :threshold_max].freeze
  MS_SLA_TREND_ATTRIBUTES = [:queue_id, :time_type, :threshold_min, :threshold_max].freeze
  MS_CALL_TREND_ATTRIBUTES = [:view, :queue_id, :time_type, :threshold_min, :threshold_max].freeze
  OMNI_CONFIG_ATTRIBUTES = [:source, :url].freeze

  WIDGETS_ATTRIBUTES_FIELDS = [widgets_attributes:
    [:widget_type, :name, :x, :y, :width, :height, :refresh_interval, :config_data] |
      SCORECARD_ATTRIBUTES |
      BAR_CHART_ATTRIBUTES |
      CSAT_ATTRIBUTES |
      LEADERBOARD_ATTRIBUTES |
      TICKET_TREND_CARD_ATTRIBUTES |
      TIME_TREND_CARD_ATTRIBUTES |
      SLA_TREND_CARD_ATTRIBUTES |
      OMNI_CONFIG_ATTRIBUTES |
      MS_AVAILABILITY_ATTRIBUTES |
      MS_TIME_TREND_ATTRIBUTES |
      MS_SLA_TREND_ATTRIBUTES |
      MS_CALL_TREND_ATTRIBUTES |
      MS_SCORECARD_ATTRIBUTES |
      MS_BAR_CHART_ATTRIBUTES |
      MS_CSAT_ATTRIBUTES].freeze

  OMNI_VALID_QUERY_PARAMS = ([:source] |
    MS_AVAILABILITY_ATTRIBUTES |
    MS_TIME_TREND_ATTRIBUTES |
    MS_SLA_TREND_ATTRIBUTES |
    MS_CALL_TREND_ATTRIBUTES |
    MS_SCORECARD_ATTRIBUTES |
    MS_BAR_CHART_ATTRIBUTES |
    MS_CSAT_ATTRIBUTES).freeze

  CREATE_FIELDS = %w(name) | ACCESSIBLE_ATTRIBUTES_FIELDS | WIDGETS_ATTRIBUTES_FIELDS
  UPDATE_FIELDS = %w(name accessible_attributes widgets_attributes)

  SCORECARD_PREVIEW_FIELDS = %w(ticket_filter_id)
  BAR_CHART_PREVIEW_FIELDS = %w(ticket_filter_id categorised_by sort representation view_all)
  LEADERBOARD_PREVIEW_FIELDS = %w(group_id)
  CSAT_PREVIEW_FIELDS = %w(group_ids time_range)
  FORUM_MODERATION_PREVIEW_FIELDS = %w().freeze
  TICKET_TREND_CARD_PREVIEW_FIELDS = %w[group_ids product_id metric date_range ticket_type].freeze
  TIME_TREND_CARD_PREVIEW_FIELDS = %w[group_ids product_id metric date_range ticket_type].freeze
  SLA_TREND_CARD_PREVIEW_FIELDS = %w[group_ids product_id metric date_range ticket_type].freeze
  BAR_CHART_DATA_FIELDS = %w(widget_id)
  CREATE_ANNOUNCEMENT_FIELDS = %w(announcement_text)
  END_ANNOUNCEMENT_FIELDS = %w(deactivate)

  VALIDATION_CLASS = 'CustomDashboardValidation'.freeze
  DELEGATOR_CLASS = 'CustomDashboardDelegator'.freeze

  ROOT_KEY = {
    widgets_data: :widgets,
    widget_data_preview: :preview_data,
    index: :dashboards,
    create: :dashboard,
    update: :dashboard,
    show: :dashboard,
    bar_chart_data: :chart_data,
    create_announcement: :announcement,
    end_announcement: :result,
    get_announcements: :announcements,
    fetch_announcement: :announcement
  }.freeze

  WIDGET_MODULES = [
    ['scorecard', 0, 'Dashboard::Custom::Scorecard'],
    ['bar_chart', 1, 'Dashboard::Custom::BarChart'],
    ['csat', 2, 'Dashboard::Custom::Csat'],
    ['leaderboard', 3, 'Dashboard::Custom::Leaderboard'],
    # ['forum_moderation', 4, 'Dashboard::Custom::ForumModerationWidget'],
    ['ticket_trend_card', 5, 'Dashboard::Custom::TicketTrendCard'],
    ['time_trend_card', 6, 'Dashboard::Custom::TimeTrendCard'],
    ['sla_trend_card', 7, 'Dashboard::Custom::SlaTrendCard'],
    ['ms_scorecard', 11, 'Dashboard::Custom::MSScorecard', 'scorecard'],
    ['ms_bar_chart', 12, 'Dashboard::Custom::MSBarChart', 'bar_chart'],
    ['ms_availability', 13, 'Dashboard::Custom::MSAvailability', 'availability'],
    ['ms_csat', 14, 'Dashboard::Custom::MSCsat', 'csat'],
    ['ms_time_trend', 16, 'Dashboard::Custom::MSTimeTrend', 'time_trend'],
    ['ms_sla_trend', 17, 'Dashboard::Custom::MSSlaTrend', 'sla_trend'],
    ['ms_call_trend', 18, 'Dashboard::Custom::MSCallTrend', 'call_trend']
  ].freeze

  GROUP_WIDGETS = ['csat', 'leaderboard', 'ticket_trend_card', 'time_trend_card', 'sla_trend_card'].freeze
  PRODUCT_WIDGETS = ['ticket_trend_card', 'time_trend_card', 'sla_trend_card'].freeze
  TICKET_FILTER_WIDGETS = ['scorecard', 'bar_chart'].freeze
  SOURCES = { :freshcaller => 'freshcaller', :freshdesk => 'freshdesk', nil => 'freshdesk', :freshchat => 'freshchat' }.freeze
  CUSTOM_DASHBOARD_SOURCES = SOURCES.values.freeze
  OMNI_DASHBOARD_SOURCES = ['freshcaller', 'freshchat'].freeze
  OMNI_WIDGETS = ['ms_scorecard', 'ms_bar_chart', 'ms_call_trend', 'ms_availability', 'ms_csat', 'ms_time_trend', 'ms_sla_trend'].freeze
  OMNI_WIDGET_INITIAL_LIMIT = { 'freshcaller_call_trend' => 0, 'freshcaller_availability' => 0, 'freshcaller_time_trend' => 0, 'freshcaller_sla_trend' => 0, 'freshchat_scorecard' => 0, 'freshchat_bar_chart' => 0, 'freshchat_availability' => 0, 'freshchat_csat' => 0, 'freshchat_time_trend' => 0 }.freeze
  FRESHDESK = 'freshdesk'.freeze
  FRESHCALLER = 'freshcaller'.freeze
  FRESHCHAT = 'freshchat'.freeze

  WIDGET_MODULES_BY_TOKEN = Hash[*WIDGET_MODULES.map { |i| [i[1], i[2]] }.flatten]
  WIDGET_MODULES_BY_NAME = Hash[*WIDGET_MODULES.map { |i| [i[1], i[0]] }.flatten]
  WIDGET_MODULES_BY_KLASS = Hash[*WIDGET_MODULES.map { |i| [i[0], i[2]] }.flatten]
  WIDGET_MODULE_NAMES = WIDGET_MODULES.map(&:first)
  WIDGET_MODULE_TOKEN_BY_NAME = Hash[*WIDGET_MODULES.map { |i| [i[0], i[1]] }.flatten]
  WIDGET_MODULES_BY_SHORT_NAME = Hash[*WIDGET_MODULES.map { |i| [i[1], i[3]] }.flatten]

  OMNI_WIDGET_TYPES = [WIDGET_MODULE_TOKEN_BY_NAME['ms_scorecard'], WIDGET_MODULE_TOKEN_BY_NAME['ms_bar_chart'], WIDGET_MODULE_TOKEN_BY_NAME['ms_availability'], WIDGET_MODULE_TOKEN_BY_NAME['ms_csat'], WIDGET_MODULE_TOKEN_BY_NAME['ms_time_trend'], WIDGET_MODULE_TOKEN_BY_NAME['ms_sla_trend'], WIDGET_MODULE_TOKEN_BY_NAME['ms_call_trend']].freeze
  OMNI_WIDGET_DATA_URL = '/api/data/widget-data?'.freeze

  # User access type doesn't apply to custom dashboards    users: 1, 
  DASHBOARD_ACCESS_TYPE = { all: 0, groups: 2 }.freeze

  NUMBER = 0
  PERCENTAGE = 1

  SCORECARD_DIMENSIONS = { height: 1, width: 1 }.freeze
  TREND_DIMENSIONS = { height: 1, width: 2 }.freeze
end
