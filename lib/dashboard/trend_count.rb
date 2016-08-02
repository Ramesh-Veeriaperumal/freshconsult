class Dashboard::TrendCount < Dashboard
  include Helpdesk::TicketFilterMethods

  attr_accessor :es_enabled, :filter_options, :trends

  DEFAULT_TREND = ["overdue", "due_today", "on_hold", "open", "unresolved", "new"]

  def initialize(es_enabled, options = {})
    @es_enabled = es_enabled
    @filter_options = options[:filter_options].presence
    @trends = options[:trends] || DEFAULT_TREND
  end

  #this handles both es and db methods internally. Existing methods.
  def fetch_count
    trends.inject({}) do |type, counter_type|
      translated_key = (counter_type == "new") ? "unassigned" : counter_type
      type.merge!({:"#{counter_type}" => {:value => filter_count(counter_type.to_sym,es_enabled), :label => I18n.t("helpdesk.dashboard.summary.#{translated_key}"), :name => counter_type}})
    end
  end

end