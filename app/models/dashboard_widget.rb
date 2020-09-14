class DashboardWidget < ActiveRecord::Base
  include ::Dashboard::Custom::CustomDashboardConstants
  self.primary_key = :id

  include Dashboard::Custom::GridConfig
  include Dashboard::Custom::ConfigData

  attr_accessible :active, :config_data, :dashboard_id,
                  :grid_config, :name, :refresh_interval, :ticket_filter_id, :widget_type, :x, :y, :width, :height,
                  :threshold_min, :threshold_max, :representation, :sort, :categorised_by, :group_id,
                  :time_range, :group_ids, :product_id, :metric, :date_range, :metric_type, :ticket_type,
                  :source, :time_type, :queue_id, :view, :url

  serialize :config_data, Hash
  serialize :grid_config, Hash

  belongs_to_account
  belongs_to :dashboard

  belongs_to :ticket_filter, class_name: 'Helpdesk::Filters::CustomTicketFilter'

  validates_presence_of :grid_config, :widget_type

  validates_inclusion_of :widget_type, in: WIDGET_MODULES_BY_TOKEN.keys

  before_save :set_active, on: :update, if: :inactive_widget_updated?
  before_save :set_url, if: :omni_widget_source?

  scope :all_active, -> { where(active: true) }
  scope :of_types, -> (types) { where(active: true, widget_type: types) }

  scope :scorecards, ->{ where(active: true, widget_type: WIDGET_MODULE_TOKEN_BY_NAME[:scorecard.to_s]) }

  scope :bar_charts, ->{ where(active: true, widget_type: WIDGET_MODULE_TOKEN_BY_NAME[:bar_chart.to_s]) }

  scope :csats, ->{ where(active: true, widget_type: WIDGET_MODULE_TOKEN_BY_NAME[:csat.to_s]) }

  scope :leaderboards, ->{ where(active: true, widget_type: WIDGET_MODULE_TOKEN_BY_NAME[:leaderboard.to_s]) }

  # scope :forum_moderations, conditions: { widget_type: WIDGET_MODULE_TOKEN_BY_NAME[:forum_moderation.to_s], active: true }

  scope :ticket_trend_cards, ->{ where(active: true, widget_type: WIDGET_MODULE_TOKEN_BY_NAME[:ticket_trend_card.to_s]) }

  scope :time_trend_cards, ->{ where(active: true, widget_type: WIDGET_MODULE_TOKEN_BY_NAME[:time_trend_card.to_s]) }

  scope :sla_trend_cards, ->{ where(active: true, widget_type: WIDGET_MODULE_TOKEN_BY_NAME[:sla_trend_card.to_s]) }

  scope :forum_moderations, ->{ where(active: true, widget_type: WIDGET_MODULE_TOKEN_BY_NAME[:forum_moderation.to_s]) }

  scope :trend_cards, ->{ where(active: true, widget_type: WIDGET_MODULE_TOKEN_BY_NAME[:trend_card.to_s]) }
  
  def inactive_widget_updated?
    # Checking for changes not active because setting active to false cannot be should not be reverted.
    !changes.keys.include?("active") && active == false
  end

  def set_active
    self.active = true
  end

  def omni_widget_source?
    Account.current.omni_channel_team_dashboard_enabled? && OMNI_DASHBOARD_SOURCES.include?(config_data[:source])
  end

  def set_url
    config_data[:url] = config_data.select { |k, v| OMNI_VALID_QUERY_PARAMS.include?(k.to_sym) && v.present? }.to_query
  end
end
