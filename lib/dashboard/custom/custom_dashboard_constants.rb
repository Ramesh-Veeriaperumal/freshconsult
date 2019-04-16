module Dashboard::Custom::CustomDashboardConstants

  WIDGETS_DATA_FIELDS = %w(type)
  WIDGET_DATA_PREVIEW_FIELDS = %w(type ticket_filter_id)

  ACCESSIBLE_ATTRIBUTES_FIELDS = [accessible_attributes: [:access_type, :group_ids]].freeze

  SCORECARD_ATTRIBUTES = [:ticket_filter_id, :threshold_max, :threshold_min].freeze
  BAR_CHART_ATTRIBUTES = [:ticket_filter_id, :categorised_by, :representation].freeze
  LEADERBOARD_ATTRIBUTES = [:group_id]
  CSAT_ATTRIBUTES = [:group_ids, :time_range]
  FORUM_MODERATION_ATTRIBUTES = []
  TICKET_TREND_CARD_ATTRIBUTES = [:group_ids, :product_id, :metric, :date_range, :threshold_max, :threshold_min].freeze
  TIME_TREND_CARD_ATTRIBUTES = [:group_ids, :product_id, :metric, :date_range, :threshold_max, :threshold_min].freeze
  SLA_TREND_CARD_ATTRIBUTES = [:group_ids, :product_id, :metric, :date_range, :threshold_max, :threshold_min].freeze

  WIDGETS_ATTRIBUTES_FIELDS = [widgets_attributes:
    [:widget_type, :name, :x, :y, :width, :height, :refresh_interval, :config_data] |
      SCORECARD_ATTRIBUTES |
      BAR_CHART_ATTRIBUTES |
      CSAT_ATTRIBUTES |
      LEADERBOARD_ATTRIBUTES |
      TICKET_TREND_CARD_ATTRIBUTES |
      TIME_TREND_CARD_ATTRIBUTES |
      SLA_TREND_CARD_ATTRIBUTES].freeze

  CREATE_FIELDS = %w(name) | ACCESSIBLE_ATTRIBUTES_FIELDS | WIDGETS_ATTRIBUTES_FIELDS
  UPDATE_FIELDS = %w(name accessible_attributes widgets_attributes)

  SCORECARD_PREVIEW_FIELDS = %w(ticket_filter_id)
  BAR_CHART_PREVIEW_FIELDS = %w(ticket_filter_id categorised_by sort representation view_all)
  LEADERBOARD_PREVIEW_FIELDS = %w(group_id)
  CSAT_PREVIEW_FIELDS = %w(group_ids time_range)
  FORUM_MODERATION_PREVIEW_FIELDS = %w().freeze
  TICKET_TREND_CARD_PREVIEW_FIELDS = %w(group_ids product_id metric date_range)
  TIME_TREND_CARD_PREVIEW_FIELDS = %w(group_ids product_id metric date_range)
  SLA_TREND_CARD_PREVIEW_FIELDS = %w(group_ids product_id metric date_range)
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
    ['sla_trend_card', 7, 'Dashboard::Custom::SlaTrendCard']
  ].freeze

  GROUP_WIDGETS = ['csat', 'leaderboard', 'ticket_trend_card', 'time_trend_card', 'sla_trend_card'].freeze
  PRODUCT_WIDGETS = ['ticket_trend_card', 'time_trend_card', 'sla_trend_card'].freeze
  TICKET_FILTER_WIDGETS = ['scorecard', 'bar_chart'].freeze

  WIDGET_MODULES_BY_TOKEN = Hash[*WIDGET_MODULES.map { |i| [i[1], i[2]] }.flatten]
  WIDGET_MODULES_BY_NAME = Hash[*WIDGET_MODULES.map { |i| [i[1], i[0]] }.flatten]
  WIDGET_MODULES_BY_KLASS = Hash[*WIDGET_MODULES.map { |i| [i[0], i[2]] }.flatten]
  WIDGET_MODULE_NAMES = WIDGET_MODULES.map(&:first)
  WIDGET_MODULE_TOKEN_BY_NAME = Hash[*WIDGET_MODULES.map { |i| [i[0], i[1]] }.flatten]

  # User access type doesn't apply to custom dashboards    users: 1, 
  DASHBOARD_ACCESS_TYPE = { all: 0, groups: 2 }.freeze

  NUMBER = 0
  PERCENTAGE = 1

  SCORECARD_DIMENSIONS = { height: 1, width: 1 }.freeze
  TREND_DIMENSIONS = { height: 1, width: 2 }.freeze
end
