# encoding: utf-8
class Search::Dashboard::Custom::Count

  include Dashboard::TrendCountMethods
  include Search::Dashboard::AggregationMethods
  
  attr_accessor :es_enabled, :filter_condition, :trends, :is_agent

  def initialize(es_enabled, options = {})
    @es_enabled = es_enabled
    @filter_condition = {}
    @trends = options[:trends]
    @aggregation_options = options[:agg_options]
    @is_agent = false
    @with_permissible = options[:with_permissible] || false
    @limit = options[:limit]
  end

  def fetch_count
    filtered_counts
  end
end
