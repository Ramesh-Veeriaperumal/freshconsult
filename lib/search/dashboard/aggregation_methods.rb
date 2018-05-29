module Search::Dashboard::AggregationMethods
  
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

  def aggregation_base(field_name,limit=100,order='desc')
    { 
      :aggs => {
        :name => {
          :terms => {
            :field  => field_name,
            :size   => limit,
            :order => { '_count' => order }
          }
        }
      }
    }
  end

  def aggregation_with_missing_field(field_name, limit = 100, include_missing = false, order = 'desc')
    aggregation_base = aggregation_base(field_name, limit, order)
    return aggregation_base unless include_missing
    aggregation_base[:aggs][:name][:terms].merge!({ missing: '-1' })
    aggregation_base
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