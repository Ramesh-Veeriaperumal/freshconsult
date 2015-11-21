# encoding: utf-8
class Search::Dashboard::Docs < Search::Filters::Docs
  attr_accessor :params, :group_by, :negative_params

  def initialize(values=[], negative_values=[],group_by=[])
    @params = (values.presence || [])
    @negative_params  = (negative_values.presence || [])
    @group_by = (group_by.presence || [])
  end

  def aggregation(model_class)
    response = es_request(model_class,'_search?search_type=count',aggregation_query)
    return JSON.parse(response)["aggregations"]["name"]["buckets"]
  end

  def missing(model_class, missing_field)
    response = es_request(model_class,'_search?search_type=count', aggregation_query)
    return JSON.parse(response)["aggregations"]["name"]["buckets"]
  end

  #only 2 group bys can be represented in UI. So directly using it instead of looping
  def aggregation_query
    return {} if group_by.blank?
    #forming base structure for aggregation
    base_hash = aggregation_base(group_by.first)
    #removing first element from array as we have already formed base
    group_by.shift
    #forming multiple aggregation
    group_by.each do |g_by|
      base_hash[:aggs][:name].merge!(aggregation_base(g_by))
    end
    base_hash
  end

  def aggregation_base(field_name, size = 1000)
    {:aggs => {:name => {:terms => {:field => field_name, :size => size}}}}
  end

end