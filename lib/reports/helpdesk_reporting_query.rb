module Reports::HelpdeskReportingQuery

  include Reports::ReportTimes

  def helpdesk_activity_query (conditions, prev_time=false)
    set_time_range(prev_time)
    r_db = Reports::RedshiftQueries.new({:start_time => @start_time, :end_time => @end_time, 
        :base_time => previous_start})
    options = {:select_cols => r_db.report_metrics, 
      :conditions => %(#{r_db.conditions} %s #{conditions}) % (conditions.blank? ? "" : "AND" )}
    result = r_db.execute(options)
    result[0].symbolize_keys!
  end

   def group_tkts_by_columns(conditions,columns={})
    set_time_range
    r_db = Reports::RedshiftQueries.new({:start_time => @start_time, :end_time => @end_time,
      :base_time => previous_start})
    options = {:select_cols => %(SUM(received_tickets) as count, #{columns[:group_by]}), 
      :conditions => %(#{r_db.conditions} %s #{conditions} AND 
      #{columns[:column_name]} IS NOT NULL) % (conditions.blank? ? "" : "AND"),
      :group_by => columns[:group_by]}
    r_db.execute(options)
  end

  def helpdesk_analysis_query (conditions, columns = {})
    r_db = Reports::RedshiftQueries.new({:start_time => @start_time, :end_time => @end_time})
    select_columns = columns[:select_columns].blank? ? r_db.report_metrics : 
        generate_select_columns(r_db, columns[:select_columns])
    options = {
    :select_cols => %(#{select_columns}, #{columns[:group_by]}), 
    :conditions => %(#{r_db.conditions} %s #{conditions}) % (conditions.blank? ? "" : "AND"),
    :group_by => columns[:group_by]}
    r_db.execute(options)
  end

 

  def top_n_analysis (conditions, columns ={})
    r_db = Reports::RedshiftQueries.new({:start_time => @start_time, :end_time => @end_time})
    options = {:select_cols => %(#{generate_select_columns(r_db, columns[:select_columns])}, #{columns[:group_by]}), 
        :conditions => %(#{r_db.conditions} %s #{conditions} AND 
          #{columns[:group_by]} IS NOT NULL) % (conditions.blank? ? "" : "AND"), 
        :group_by => columns[:group_by], :order_by => columns[:order_by],:limit => columns[:limit]}
    r_db.execute(options)
  end

  def comparison_report(conditions,columns={})
    r_db = Reports::RedshiftQueries.new({:start_time => @start_time, :end_time => @end_time})
    options = {:select_cols => %(#{generate_select_columns(r_db, columns[:select_columns])}, 
      #{columns[:group_by]}, report_table.created_at), 
      :conditions => %(#{r_db.conditions} %s #{conditions} AND 
        #{columns[:group_by]} IS NOT NULL) % (conditions.blank? ? "" : "AND"),
      :group_by => %(report_table.created_at, #{columns[:group_by]})}
    r_db.execute(options)
  end

  def get_labels(id_arr, group_by)
    model = ('responder_id').eql?(group_by) ? User : ('group_id').eql?(group_by) ? Group : Customer
    deleted_label = ('responder_id').eql?(group_by) ? I18n.t("adv_reports.deleted_agent") : (('group_id').eql?(group_by) ? 
        I18n.t("adv_reports.deleted_group") : I18n.t("adv_reports.deleted_customer"))
    xaxis_Hash = model.find_all_by_id(id_arr).inject({}) do |result_hash, u| 
     result_hash[u.id] = u.name
     result_hash
    end
    id_arr.each {|id| xaxis_Hash[id.to_i] = deleted_label unless xaxis_Hash.key?(id.to_i)} if id_arr.length != xaxis_Hash.length
    xaxis_Hash
  end

# generate select columns from the select columns string like 'received_tickets,resolved_tickets,backlog_tickets'
  def generate_select_columns(r_db, select_columns)
    column_array = select_columns.split(";").collect do |c|
      args = c.split(",")
      method = args.shift
      args.blank? ? r_db.send("select_#{method}") : r_db.send("select_#{method}",args)
    end
    column_array.join(",")
  end

end