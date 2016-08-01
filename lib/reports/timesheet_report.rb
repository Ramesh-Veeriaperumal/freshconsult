module Reports::TimesheetReport
  
  include Reports::ActivityReport
  include HelpdeskReports::Helper::ControllerMethods

  TIMESHEET_ROWS_LIMIT = 100

  BATCH_LIMIT_FOR_EXPORT = 2000

  GROUP_TO_FIELD_MAP = {
    :customer_name => "owner_id",
    :agent_name => "user_id",
    :group_name => "group_id",
    :product_name => "product_id",
    :workable => "display_id",
    :group_by_day_criteria => 'executed_at_date'
  }

  def valid_month?(time)
    time.is_a?(Numeric) && (1..12).include?(time)
  end
  
  def start_of_month(month=Time.current.month)
    Time.utc(Time.now.year, month, 1) if valid_month?(month)
  end
  
  def end_of_month(month)
    start_of_month(month).end_of_month
  end
  
  def csv_hash
    {"Agent"=>:agent_name, "Hours"=> :hours, "Date" =>:executed_at ,"Ticket"=>:ticket_display, 
                                 "Product"=>:product_name , "Group"=>:group_name , "Note"=>:note,
                                 "Customer" => :customer_name ,"Billable/Non-Billable" => :billable_type,
                                 "Priority"=>:priority_name, "Status"=>:status_name,
                                  "Created at" => :created_at}
  end
  
  def list_view_items
    view_headers = [:workable , :customer_name , :priority_name, :status_name, :note , :group_by_day_criteria , :agent_name,
                                                                             :group_name ]

    view_headers -= [:agent_name] if Account.current.features_included?(:euc_hide_agent_metrics)
    view_headers.push(:product_name) if Account.current.products.any?
    view_headers.push(:hours)
    view_headers
  end

  def billable_vs_non_billable(time_sheets)
    total_time = 0.0
    billable_data = 0.0
    time_sheets.each do |group,time_entries|
      time_entries.each do |time_entry|
        total_time+=time_entry.running_time
        billable_data += time_entry.running_time if time_entry.billable
      end
    end
    { :total_time => total_time, :billable => billable_data, :non_billable => (total_time - billable_data) }
  end
  
  def scoper(start_date,end_date)
    scope = Account.current.time_sheets.for_companies(@customer_id).by_agent(@user_id).by_group(@group_id).created_at_inside(start_date,end_date).hour_billable(@billable).for_products(@products_id)
    # Joining with schema_less_tickets only when requested for 'group by product'
    scope = scope.joins('INNER JOIN helpdesk_schema_less_tickets on  helpdesk_schema_less_tickets.ticket_id = helpdesk_time_sheets.workable_id') if group_by_caluse == :product_name
    scope
  end

  def filter_with_groupby(start_date,end_date)
    filter(start_date,end_date).group_by(&group_by_caluse)
  end 

  def csv_filter(start_date,end_date)
    time_sheets_non_archive = []
      scoper(start_date,end_date).find_in_batches(:batch_size => BATCH_LIMIT_FOR_EXPORT,:conditions => (select_conditions || {}), 
                :include => [:user, :workable => [:schema_less_ticket, :group, :ticket_status, :requester, :company]]) do |time_sheets_batch|# need to ensure - Hari
        time_sheets_non_archive << time_sheets_batch
      end
    time_sheets_non_archive.flatten
  end

  def group_to_column_map(group,archive=false)
    # ticket_table_name = archive ? Helpdesk::ArchiveTicket.table_name : Helpdesk::Ticket.table_name
    time_sheet_group_to_column_map = {
      :customer_name => "#{archive ? Helpdesk::ArchiveTicket.table_name : Helpdesk::Ticket.table_name}.owner_id",
      :agent_name    => "#{Helpdesk::TimeSheet.table_name}.user_id",
      :group_name    => "#{archive ? Helpdesk::ArchiveTicket.table_name : Helpdesk::Ticket.table_name}.group_id",
      :product_name  => "#{archive ? Helpdesk::ArchiveTicket.table_name : Helpdesk::SchemaLessTicket.table_name}.product_id",
      :workable      => "#{archive ? Helpdesk::ArchiveTicket.table_name : Helpdesk::Ticket.table_name}.display_id",
      :group_by_day_criteria => "DATE(#{Helpdesk::TimeSheet.table_name}.executed_at) as executed_at_date"
    }
    time_sheet_group_to_column_map[group]
  end

  def fetch_summary(archive=false)
    if archive
      archive_scoper(previous_start, @end_date).select("
        (case when (helpdesk_time_sheets.executed_at >= '#{@start_date}') then 1 else 0 END) as current,
        helpdesk_time_sheets.billable,
        sum(case when timer_running = 0 then helpdesk_time_sheets.time_spent else time_to_sec(timediff('#{@load_time}', start_time)) + helpdesk_time_sheets.time_spent END) as time_spent,
        helpdesk_time_sheets.workable_type,
        count(*) as count,
        archive_tickets.id,
        max(helpdesk_time_sheets.id) as max_timesheet_id,
        helpdesk_time_sheets.workable_id,
        #{GROUP_TO_FIELD_MAP[group_by_caluse] == 'executed_at_date' ? 'DATE(executed_at) as executed_at_date' : GROUP_TO_FIELD_MAP[group_by_caluse]}
        ").group("#{GROUP_TO_FIELD_MAP[group_by_caluse]}, current, billable").find(:all, :conditions => (archive_select_conditions || {}),
        :include => [:user, :workable => [:product, :group, :ticket_status, :requester, :company]])
    else
      scoper(previous_start, @end_date).select("
        (case when (helpdesk_time_sheets.executed_at >= '#{@start_date}') then 1 else 0 END) as current,
        helpdesk_time_sheets.billable,
        sum(case when timer_running = 0 then helpdesk_time_sheets.time_spent else time_to_sec(timediff('#{@load_time}', start_time)) + helpdesk_time_sheets.time_spent END) as time_spent,
        helpdesk_time_sheets.workable_type,
        count(*) as count,
        helpdesk_tickets.id,
        max(helpdesk_time_sheets.id) as max_timesheet_id,
        helpdesk_time_sheets.workable_id,
        #{GROUP_TO_FIELD_MAP[group_by_caluse] == 'executed_at_date' ? 'DATE(executed_at) as executed_at_date' : GROUP_TO_FIELD_MAP[group_by_caluse]}
        ").group("#{GROUP_TO_FIELD_MAP[group_by_caluse]}, current, billable").find(:all, :conditions => (select_conditions || {}),
        :include => [:user, :workable => [:schema_less_ticket, :group, :ticket_status, :requester, :company]])
    end
  end

  def fetch_timesheet_entries(offset=0, row_limit=nil)
    row_limit ||= @pdf_export ? BATCH_LIMIT_FOR_EXPORT : TIMESHEET_ROWS_LIMIT
    entries = scoper(@start_date, @end_date).where("helpdesk_time_sheets.id <= #{@latest_timesheet_id}").select("helpdesk_time_sheets.*, #{group_to_column_map(group_by_caluse, false)}").reorder("#{GROUP_TO_FIELD_MAP[group_by_caluse]}, id asc").find(:all, :limit => row_limit, :offset => offset,:conditions => (select_conditions || {}),
      :include => [:user, :workable => [:schema_less_ticket, :group, :ticket_status, :requester, :company]])
    if (archive_enabled? && entries.size < row_limit)
      entries << archive_scoper(@start_date, @end_date).where("helpdesk_time_sheets.id <= #{@latest_timesheet_id}").select("helpdesk_time_sheets.*, #{group_to_column_map(group_by_caluse, true)}").reorder("#{GROUP_TO_FIELD_MAP[group_by_caluse]}, id asc").find(:all, :limit => row_limit, :offset => offset,:conditions => (archive_select_conditions || {}),
          :include => [:user, :workable => [:schema_less_ticket, :group, :ticket_status, :requester, :company]])
    end
    entries
  end

  def time_sheet_list
    if params[:scroll_position]
      construct_timesheet_entries
    else
      @report_date = params[:date_range]
      @load_time = Time.now.utc
      @summary = fetch_summary
      @summary << fetch_summary(true) if archive_enabled?
      construct_timesheet_metric_data
      stacked_chart_data
      @time_sheets = timesheet_entries(0, 2000)
      @ajax_params = {scroll_position: 20, row_count: 2000, group_by: group_by_caluse.to_s}
    end
  end

  def time_sheet_list_pdf
    @load_time = Time.now.utc
    @report_date = params[:date_range]
    @summary = fetch_summary
    @summary << fetch_summary(true) if archive_enabled?
    construct_timesheet_metric_data
    stacked_chart_data
    @time_sheets = timesheet_entries
    offset = BATCH_LIMIT_FOR_EXPORT
    while(offset < @row_count)
      result = timesheet_entries(offset)
      result.each do |group,value|
        @time_sheets[group] ||= []
        @time_sheets[group] += value
      end
      offset += BATCH_LIMIT_FOR_EXPORT
    end
  end

  # def time_sheet_list
  #   @report_date = params[:date_range]
  #   current_range_time_sheet
  #   previous_range_time_sheet #Fetching the previous time range data.
  #   if Account.current.features_included?(:archive_tickets)
  #     archive_current_range_time_sheet
  #     archive_previous_range_time_sheet
  #     sum_new_and_archived
  #     sum_data
  #   end
  #   @num_rows = @time_sheets.values.flatten.size
  #   @time_sheets = timesheet_limit_rows
  #   stacked_chart_data
  # end

  def previous_range_time_sheet
    #set the time (start/end) to previous range for comparison summary.
    set_time_range(true)
    old_time_sheets = filter_with_groupby(@start_time,@end_time)
    @old_time_sheet_data = billable_vs_non_billable(old_time_sheets)
  end

  def time_sheet_for_export
    @load_time = Time.now.utc
    @time_sheets = csv_filter(@start_date,@end_date)
    if Account.current.features_included?(:archive_tickets)
      @archive_time_sheets = csv_archive_filter(@start_date,@end_date)
      # @time_sheets = shift_merge_sorted_arrays(@time_sheets,@archive_time_sheets)
      @time_sheets += @archive_time_sheets
    end
  end
  #************************** Archive methods start here *****************************#

  def archive_scoper(start_date,end_date)
    Account.current.archive_time_sheets.archive_for_companies(@customer_id).by_agent(@user_id).archive_by_group(@group_id).created_at_inside(start_date,end_date).hour_billable(@billable).archive_for_products(@products_id)
  end

  def archive_filter_with_groupby(start_date,end_date)
    archive_filter(start_date,end_date).group_by(&group_by_caluse)
  end 

  def csv_archive_filter(start_date,end_date)
    time_sheets_archive = []
    archive_scoper(start_date,end_date).find_in_batches(:batch_size => BATCH_LIMIT_FOR_EXPORT, :conditions => (archive_select_conditions || {}), 
            :include => [:user, :workable => [:product, :group, :ticket_status, :requester, :company]]) do |time_sheets_batch|# need to ensure - Hari
      time_sheets_archive << time_sheets_batch
    end
    time_sheets_archive.flatten
  end

  def archive_select_conditions
    conditions = {}
    conditions[:ticket_type] = @ticket_type unless @ticket_type.empty? 
    conditions[:priority] = @priority unless @priority.empty?
    {:archive_tickets => conditions} unless conditions.blank?
  end

  #************************** Archive methods stop here *****************************#

  private

  def run_on_slave(&block)
    Sharding.run_on_slave(&block)
  end

  def select_conditions
    conditions = {}
    conditions[:ticket_type] = @ticket_type unless @ticket_type.empty? 
    conditions[:priority] = @priority unless @priority.empty?
    {:helpdesk_tickets => conditions} unless conditions.blank?
  end

  def set_selected_tab
    @selected_tab = :reports
  end

  def set_report_type
    @report_type         = :timesheet_reports
    @user_time_zone_abbr = Time.zone.now.zone
  end
  
  def build_item
    @current_params = {
      :start_date  => start_date,
      :end_date    => end_date,
      :customer_id => params[:customers] ? params[:customers].split(',') : [],
      :user_id     => (Account.current.features_included?(:euc_hide_agent_metrics) ? [] : (params[:user_id] || [])),
      :headers     => list_view_items.delete_if{|item| item == group_by_caluse },
      :billable    => billable_and_non? ? [true, false] : [params[:billable].to_s.to_bool],
      :group_id    => params[:group_id] || [],
      :ticket_type => params[:ticket_type] || [],
      :products_id => params[:products_id] || [],
      :priority    => params[:priority] || []
    }
    @current_params.each{ |name, value| instance_variable_set("@#{name}", value) }
  end

  def billable_and_non?
    params[:billable].blank? or (params[:billable].include?("true") and params[:billable].include?("false"))
  end

  def group_by_caluse
    group_by_caluse = params[:group_by] || :customer_name
    group_by_caluse = group_by_caluse.to_sym()
  end

def set_time_range(prev_time = false)
    @start_time = prev_time ? previous_start : start_date
    @end_time = prev_time ? previous_end : end_date  
  end
  
  
  def current_range_time_sheet
    @time_sheets = filter_with_groupby(@start_date,@end_date)    
    @time_sheet_data = billable_vs_non_billable(@time_sheets)
  end

  def check_permission
    access_denied unless privilege?(:view_time_entries)
  end

  def stacked_chart_data
    barchart_data = [{:name=>"non_billable",:data=>[@metric_data[:current][:non_billable]],:color=>'#bbbbbb'},{:name=>"billable",:data=>[@metric_data[:current][:billable]],:color=>'#679d46'}]
    @activity_data_hash={'barchart_data'=>barchart_data}
  end

  def parse_date(date_time)
    date_time.strftime("%Y-%m-%d %H:%M:%S")
  end

  #******** Archive method starts here ********#
  
  def archive_previous_range_time_sheet
    #set the time (start/end) to previous range for comparison summary.
    set_time_range(true)
    old_time_sheets = archive_filter_with_groupby(@start_time,@end_time)
    @archive_old_time_sheet_data= billable_vs_non_billable(old_time_sheets)
  end

  def archive_current_range_time_sheet
    @archive_time_sheets = archive_filter_with_groupby(@start_date,@end_date)    
    @archive_time_sheet_data = billable_vs_non_billable(@archive_time_sheets)
  end

  def sum_new_and_archived
    @time_sheet_data.each do |key,value|
      @time_sheet_data[key] = value + @archive_time_sheet_data[key]
    end
    @old_time_sheet_data.each do |key,value|
      @old_time_sheet_data[key] = value + @archive_old_time_sheet_data[key]
    end
  end

  def sum_data
    @archive_time_sheets.each do |key,value|
      if @time_sheets[key]
        @time_sheets[key] = shift_merge_sorted_arrays(@time_sheets[key],value)
      else
        @time_sheets[key] = value
      end
    end
  end

  def shift_merge_sorted_arrays(array1,array2)
    output = []
    loop do
      break if array1.empty? || array2.empty?
      output << (array1.first.executed_at > array2.first.executed_at ? array1.shift : array2.shift)
    end
    return output + array1 + array2
  end

  #******** Archive method ends here ********#
  def construct_timesheet_metric_data
    @metric_data = {:previous => {:total_time => 0, :billable => 0, :non_billable =>0},
                    :current  => {:total_time => 0, :billable => 0, :non_billable =>0}}
    @row_count = 0
    @group_count = Hash.new(0)
    @group_names = Hash.new('')
    @summary.flatten.each do |entry|
      @metric_data[entry.current == 0 ? :previous : :current][entry.billable ? :billable : :non_billable] += (entry.time_spent || 0)
      @metric_data[entry.current == 0 ? :previous : :current][:total_time] += (entry.time_spent || 0)
      if entry.current == 1
        @row_count += (entry.count || 0)
        @group_count[entry.send(GROUP_TO_FIELD_MAP[group_by_caluse]) || 0] += (entry.time_spent || 0)
        if @group_names[entry.send(GROUP_TO_FIELD_MAP[group_by_caluse])].blank?
          if group_by_caluse == :workable
            @group_names[entry.send(GROUP_TO_FIELD_MAP[group_by_caluse])] = "#{entry.send(group_by_caluse).subject.gsub("'",'')} (##{entry.send(group_by_caluse).display_id})"
          elsif group_by_caluse == :group_by_day_criteria
            @group_names[entry.send(GROUP_TO_FIELD_MAP[group_by_caluse])] = entry.send('executed_at_date')
          else
            @group_names[entry.send(GROUP_TO_FIELD_MAP[group_by_caluse]) || 0] = entry.send(group_by_caluse).gsub("'",'')
          end
        end
      end
    end
    [:total_time, :billable, :non_billable].each do |type|
      @metric_data[:previous][type] /= 3600.0
      @metric_data[:current][type] /= 3600.0
    end
    @latest_timesheet_id = @summary.collect(&:max_timesheet_id).max
    @group_count = Hash[ @group_count.collect {|k,v| [k, v/3600.0] } ]
  end

  def timesheet_entries(offset=0, row_limit=nil)
    #To handle initial page load case
    entries = fetch_timesheet_entries(offset, row_limit)
    result = {}
    entries.each do |entry|
      result[entry.send(GROUP_TO_FIELD_MAP[group_by_caluse])] ||= []  
      result[entry.send(GROUP_TO_FIELD_MAP[group_by_caluse])] << entry
    end
    result.map{|k,v| [(k.nil? ? 0 : k), v]}.to_h
  end

  def construct_timesheet_entries
    params[:current_params].each { |name, value| instance_variable_set("@#{name}", (value || [])) }
    offset = params[:scroll_position].to_i * TIMESHEET_ROWS_LIMIT
    @current_group = [group_by_caluse]
    [:totaltime, :group_names, :latest_timesheet_id].each { |param| instance_variable_set("@#{param}", params[param])}
    @load_time = Time.parse("#{params[:load_time]}")
    @time_sheets = timesheet_entries(offset)
    @time_sheets.each do |key, entries|
      if group_by_caluse == :group_by_day_criteria
        entries.select!{|entry| ((key == Date.strptime(params[:previous_group_id], "%Y-%m-%d") && entry.id >= params[:previous_entry_id].to_i) || (key > Date.strptime(params[:previous_group_id], "%Y-%m-%d")))}
      else
        entries.select!{|entry| ((key == params[:previous_group_id].to_i && entry.id >= params[:previous_entry_id].to_i) || (key > params[:previous_group_id].to_i))}
      end
    end
    @time_sheets.stringify_keys!
    @group_count = params[:group_count]
    unless @time_sheets.empty?
      @current_group_id = @time_sheets.keys.last
    end
    @headers = list_view_items.delete_if{|item| item == group_by_caluse }
    @colspan = @headers.length-1
    @ajax_params = {scroll_position: params[:scroll_position], row_count: offset, group_by: [group_by_caluse], group_header: params[:previous_group_id]}
    @current_params = params[:current_params]
  end

  def archive_enabled?
    @archive_enabled ||= Account.current.features_included?(:archive_tickets)
  end
  
end