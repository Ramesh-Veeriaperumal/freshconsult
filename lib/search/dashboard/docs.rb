# encoding: utf-8
class Search::Dashboard::Docs < Search::Filters::Docs
  attr_accessor :params, :group_by, :negative_params, :include_missing, :options

  def initialize(values=[], negative_values=[], group_by=[], options = {})
    @params           = (values.presence || [])
    @negative_params  = (negative_values.presence || [])
    @group_by         = (group_by.presence || [])
    @options          = options
    @include_missing  = options[:include_missing] || false
  end

  def aggregation(model_class)
    response = es_request(model_class,'_search?search_type=count', aggregation_query)
    parsed_response = JSON.parse(response)
    Rails.logger.info "ES response:: Account -> #{Account.current.id}, Took:: #{parsed_response['took']}"
    parsed_response["aggregations"]
  end

  private 

  #only 2 group bys can be represented in UI. So directly using it instead of looping
  def aggregation_query
    return {} if group_by.blank?
    #forming base structure for aggregation
    base_hash = aggregation_base(group_by.first, options[:first_limit])
    base_hash[:aggs].merge!(missing_block(group_by.first)) if include_missing
    #removing first element from array as we have already formed base
    group_by.shift
    #forming multiple aggregation
    group_by.each do |g_by|
      base_hash[:aggs][:name].merge!(aggregation_base(g_by,options[:second_limit]))
    end
    base_hash
  end

  def aggregation_base(field_name,limit=100)
    { 
      :aggs => {
        :name => {
          :terms => {
            :field  => field_name, 
            :size   => limit
          }
        }
      }
    }
  end

  def missing_block(field_name)
    {
      :missing_field => {
        :missing => {
          :field => field_name
        }
      }
    }
  end

end