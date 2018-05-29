class Dashboard::Custom::Leaderboard < Dashboards
  include ::Dashboard::LeaderboardMethods

  CONFIG_FIELDS = [:group_id].freeze
  CACHE_EXPIRY = 3600
  ERROR_OPTIONS = { group_id: { fields: 'group_id' } }.freeze

  attr_accessor :options

  class << self
    include Dashboard::Custom::WidgetConfigValidationMethods

    def valid_config?(options)
      return { feature: 'gamification' } unless Account.current.gamification_enabled? && Account.current.gamification_enable_enabled?
      CONFIG_FIELDS.each do |field|
        return ERROR_OPTIONS[field] unless safe_send("validate_#{field}", options[field])
      end
      true
    end
  end

  def initialize(dashboard, options = {})
    @dashboard = dashboard
    @options = options
    @result = []
  end

  def result
    fetch_result
    @result
  end

  def preview
    @options[:group_id] = nil if @options[:group_id].to_i.zero?
    result = mini_list_without_cache(@options[:group_id].presence, false)
    { data: result }
  end

  private

    def fetch_result
      @dashboard.leaderboard_widgets_from_cache.each do |widget|
        options = widget.config_data.slice(:group_id)
        options[:group_id] = nil if options[:group_id].to_i.zero?
        result = mini_list_without_cache(options[:group_id].presence, false)
        @result << { id: widget.id, widget_data: result }
      end
    end
end
