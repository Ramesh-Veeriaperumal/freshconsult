class Dashboard::Custom::ForumModerationWidget < Dashboards
  include Community::ModerationCount

  CACHE_EXPIRY = 3600
  CONFIG_FIELDS = [].freeze

  attr_accessor :options

  class << self
    def valid_config?(options)
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
    fetch_spam_counts
  end

  private

    def fetch_result
      result  =  fetch_spam_counts
      @dashboard.forum_moderation_widgets_from_cache.each do |widget|
        @result << { id: widget.id, widget_data: result }
      end
    end
end
