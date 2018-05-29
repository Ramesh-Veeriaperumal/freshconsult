class Dashboard::TrendCount < Dashboards

  include Dashboard::TrendCountMethods

  attr_accessor :es_enabled, :filter_condition, :trends, :is_agent

  def initialize(es_enabled, options = {})
    @es_enabled = es_enabled
    @filter_condition = options[:filter_options].presence || {}
    @trends = options[:trends] || DEFAULT_TREND
    @is_agent = options[:is_agent]
    @with_permissible = options[:with_permissible]
  end

  #this handles both es and db methods internally. Existing methods.
  def fetch_count
    #not handling DB for CD
    if es_enabled && Account.current.es_msearch_enabled?
      filtered_counts
    else
      trends.inject({}) do |type, counter_type|
        type.merge!({:"#{counter_type}" => filtered_doc_count(counter_type.to_s)})
      end
    end
  end
end

# ----- Sample calls -----
#  Dashboard::TrendCount.new(false,{:filter_options => {:group_id => [1,2]}}).fetch_count
# Dashboard::TrendCount.new(false,{:filter_options => {:group_id => [1,3], :product_id => [1,2]}}).fetch_count
# Dashboard::TrendCount.new(false).fetch_count
