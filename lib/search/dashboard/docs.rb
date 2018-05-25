# encoding: utf-8
class Search::Dashboard::Docs < Search::Filters::Docs

  include Search::Dashboard::AggregationMethods
  
  attr_accessor :params, :group_by, :negative_params, :include_missing, :options

  def initialize(values=[], negative_values=[], group_by=[], options = {})
    @params           = (values.presence || [])
    @negative_params  = (negative_values.presence || [])
    @group_by         = (group_by.presence || [])
    @options          = options
    @include_missing  = options[:include_missing] || false
  end

  def aggregation(model_class)
    response = es_request(model_class,'_search', aggregation_query, { :search_type => "count"})
    parsed_response = JSON.parse(response)
    Rails.logger.info "ES response:: Account -> #{Account.current.id}, Took:: #{parsed_response['took']}"
    parsed_response["aggregations"]
  end
end