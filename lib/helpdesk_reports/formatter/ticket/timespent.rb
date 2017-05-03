class HelpdeskReports::Formatter::Ticket::Timespent
  include HelpdeskReports::Util::Ticket
  include HelpdeskReports::Helper::ReportsHelper

  attr_accessor :result, :group_by, :output, :verb, :metric, :deleted_name_hash

  def initialize(data, args={})
    @result = data
    @args = args
    @group_by = args[:group_by].first
  end

  def perform
    @output = Hash.new{|hash,key| hash[key]={}}
    final_output = []
    @field_name_hash = {}
    @metric = result.keys.first
    result.each{|metric,res| return [] if (res.is_a?(Hash) && res["errors"].present?) }
    @field_name_hash['group_by'] = field_id_to_name_mapping(group_by).stringify_keys
    @deleted_tracker = 0
    @deleted_name_hash = {l1: {}, l2: {}, l3: {}}
    if metric == 'LIFECYCLE_GROUPBY'
      @verb = group_by=='group_id' ? 'agent_id' : 'group_id'
      @field_name_hash['value'] = field_id_to_name_mapping(verb).stringify_keys
      set_groupby_values
      sorted_group =  @field_name_hash['group_by'].values & output.keys
      final_output << output["None"] if output.keys.include?("None")
      deleted_fields = output.keys - sorted_group - ["None"]
      sorted_group.each{|grp| final_output << output[grp]} if sorted_group.present?
      deleted_fields.each{|grp| final_output << output[grp]} if deleted_fields.present?
      final_output.flatten!
    else
      @verb = 'status'
      @field_name_hash['value'] = field_id_to_name_mapping(verb).stringify_keys
      set_status_group_by_values
      final_output = output
    end
  
    final_output
  end

  def set_groupby_values
    result.each do |metric, res_arr|
      set_overall_groupby_values res_arr
      set_category_values res_arr
    end
  end

  def set_overall_groupby_values res_arr
    res_arr.each do |res_hash|
      grp_by_name = res_hash[group_by] ? @field_name_hash['group_by'][res_hash[group_by]] : 'None'
      deleted = grp_by_name ? false : true
      grp_by_name ||= get_deleted_name(:l1, res_hash[group_by])
      output[grp_by_name][:name] ||= deleted ? 'Deleted' : grp_by_name
      output[grp_by_name][:id] ||= res_hash[group_by] || "-1"
      output[grp_by_name][:total_time] ||= 0
      output[grp_by_name][:total_time] +=res_hash['total_time'].to_i
    end
  end

  def set_category_values res_arr
    res_arr.each do |res_hash|
      grp_by_name = res_hash[group_by] ? @field_name_hash['group_by'][res_hash[group_by]] : 'None'
      grp_by_name ||= get_deleted_name(:l1, res_hash[group_by])
      value_name = res_hash[verb] ? @field_name_hash['value'][res_hash[verb]] : 'None'
      deleted = value_name ? false : true
      value_name ||= get_deleted_name(:l2, res_hash[verb])
      output[grp_by_name][:category_sort_by_total] ||= []
      output[grp_by_name][:category_sort_by_avg] ||= []
      output[grp_by_name][:category] ||= {}
      res = set_val(res_hash, value_name, output[grp_by_name][:total_time].to_i, deleted)
      output[grp_by_name][:category].merge!(res)
      output[grp_by_name][:category_sort_by_total] << [value_name, res_hash['total_time'].to_i]
      output[grp_by_name][:category_sort_by_avg] << [value_name, res[value_name][:avg_time]]
    end
    output.each { |grp, value_hash| output[grp].merge!(set_category_sort_order(value_hash,true)) }
  end

  def set_status_group_by_values
    group_total_time = 0
    output[:status_category] = {}
    output[:status_category][:category_sort_by_total] = []
    result.each do |metric, res_arr|
      res_arr.each {|res_hash| group_total_time += res_hash['total_time'].to_i}
      res_arr.each do |res_hash|
        value_name = @field_name_hash['value'][res_hash[verb]]
        deleted = value_name ? false : true
        value_name ||= get_deleted_name(:l3, res_hash[verb])
        res = set_val(res_hash, value_name, group_total_time,deleted)
        output[:status_category].merge!(res)
        output[:status_category][:category_sort_by_total] << [value_name, res_hash['total_time'].to_i]
      end
    end
    output[:status_category].merge!(set_category_sort_order(output[:status_category]))
  end

  def set_val(res_hash, value_name, overall_time, deleted=false)
    res = Hash.new { |hash, key| hash[key] = {} }    
    res[value_name][:id] = res_hash[verb] || "-1"
    res[value_name][:name] = deleted ? 'Deleted' : value_name
    res[value_name][:tkt_count] = res_hash['tkt_count']
    res[value_name][:total_time] = res_hash['total_time']
    res[value_name][:avg_time] = (res_hash['total_time'].to_f / res_hash['tkt_count'].to_f).round(2)
    res[value_name][:percent_time] = ((res_hash['total_time'].to_f/overall_time)*100).round(2)
    res
  end

  def set_category_sort_order(value_hash,sort_by_avg=false)
    sort_hash = {
      category_sort_by_total: value_hash[:category_sort_by_total].sort_by{|sort_arr| sort_arr[1]}.reverse.map{|sort_arr| sort_arr[0]}
    }
    sort_hash.merge!(category_sort_by_avg: value_hash[:category_sort_by_avg].sort_by{|sort_arr| sort_arr[1]}.reverse.map{|sort_arr| sort_arr[0]}) if sort_by_avg
    sort_hash
  end

  def get_deleted_name(level, id)
    unless deleted_name_hash[level][id]
      deleted_name_hash[level][id] = "deleted_#{@deleted_tracker}"
      @deleted_tracker += 1
    end
    deleted_name_hash[level][id]
  end

end