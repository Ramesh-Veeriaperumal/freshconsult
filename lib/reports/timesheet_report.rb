module Reports::TimesheetReport

  include Reports::ActivityReport
  include HelpdeskReports::Helper::ControllerMethods
  include Reports::TimeSheetReportFields
  include HelpdeskReports::Constants

  TIMESHEET_ROWS_LIMIT = 30

  BATCH_LIMIT_FOR_EXPORT = 2000

  MULTI_SELECT_LIMIT = 50

  TICKET_FILTER_LIMIT = 13

  VALIDATIONS = ["validate_max_filters", "validate_max_multi_selects"]

  GROUP_TO_FIELD_MAP = {
    :customer_name => "owner_id",
    :agent_name => "user_id",
    :group_name => "group_id",
    :product_name => "product_id",
    :workable => "display_id",
    :group_by_day_criteria => 'executed_at'
  }

  ALIAS_GROUP_NAME = {
    :customer_name => "customer_id",
    :agent_name => "user_id",
    :group_name => "group_id",
    :product_name => "product_id",
    :workable => "display_id",
    :group_by_day_criteria => "executed_at"
  }

  OPTIONAL_COLUMN_CONFIG = {
    :note => I18n.t('helpdesk.time_sheets.note'),
    :requester_name => I18n.t('helpdesk.time_sheets.requester_name'),
    :ticket_type => I18n.t('helpdesk.time_sheets.ticket_type')
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

  def construct_csv_headers_hash
    default_colset = {
      I18n.t('helpdesk.time_sheets.agent')=>:agent_name,
      I18n.t('helpdesk.time_sheets.hours')=> :hours,
      I18n.t('helpdesk.time_sheets.date') =>:executed_at ,
      I18n.t('helpdesk.time_sheets.ticket')=>:ticket_display,
      I18n.t('helpdesk.time_sheets.product')=>:product_name ,
      I18n.t('helpdesk.time_sheets.group')=>:group_name ,
      I18n.t('helpdesk.time_sheets.note')=>:note,
      I18n.t('helpdesk.time_sheets.customer') => :customer_name ,
      I18n.t('helpdesk.time_sheets.billalblenonbillable') => :billable_type,
      I18n.t('helpdesk.time_sheets.priority')=>:priority_name,
      I18n.t('helpdesk.time_sheets.status')=>:status_name,
    I18n.t('helpdesk.time_sheets.createdAt') => :created_at}
    selected_colset = transform_selected_columns

    default_colset.merge(selected_colset)
  end


  def build_master_column_header_hash
    columns_hash_arr = [Helpdesk::TimeSheet.report_list, OPTIONAL_COLUMN_CONFIG, custom_column_master_hash]
    @master_column_header_hash = Hash[*columns_hash_arr.map(&:to_a).flatten]
  end

  def transform_selected_columns
    cols = Hash.new
    custom_col_hash = OPTIONAL_COLUMN_CONFIG.merge(custom_column_master_hash)
    @time_sheet_columns.each do |column_key|
      cols[custom_col_hash[column_key.to_sym]] = column_key
    end
    cols
  end

  def list_view_items
    view_headers = [:workable , :customer_name , :priority_name, :status_name , :group_by_day_criteria , :agent_name,
                    :group_name ]

    view_headers -= [:agent_name] if Account.current.hide_agent_metrics_feature?
    view_headers.push(:product_name) if Account.current.products.any?
    view_headers.concat(@time_sheet_columns.map(&:to_sym))
    view_headers.push(:hours)
    view_headers.uniq
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
    scope = scope.joins('INNER JOIN helpdesk_schema_less_tickets on  helpdesk_schema_less_tickets.ticket_id = helpdesk_time_sheets.workable_id and helpdesk_schema_less_tickets.account_id = helpdesk_time_sheets.account_id  ') if group_by_caluse == :product_name && @products_id.blank?

    select_flexiconditions

    if @flexi_conditions.present?
      scope = scope.joins('INNER JOIN flexifields ON flexifields.flexifield_set_id = helpdesk_tickets.id and flexifields.account_id = helpdesk_tickets.account_id').where(:flexifields => @flexi_conditions) #if !@flexi_conditions.blank?
    elsif @request_custom_fields_columns.any?
      scope = scope.joins('INNER JOIN flexifields ON flexifields.flexifield_set_id = helpdesk_tickets.id and flexifields.account_id = helpdesk_tickets.account_id')
    end
    scope
  end

  def filter_with_groupby(start_date,end_date)
    filter(start_date,end_date).group_by(&group_by_caluse)
  end

  def csv_filter(start_date,end_date)
    time_sheets_non_archive = []
    scoper(start_date,end_date).select(" #{construct_custom_column_select_statement} helpdesk_time_sheets.*   ").find_in_batches(:batch_size => BATCH_LIMIT_FOR_EXPORT,:conditions => (select_conditions || {}),
    :include => [:user, :workable => [:schema_less_ticket, :group, :ticket_status, :requester, :company]]) do |time_sheets_batch|# need to ensure - Hari
      time_sheets_non_archive << time_sheets_batch
    end
    time_sheets_non_archive.flatten
  end

  def group_to_column_map(group,archive=false)
    # ticket_table_name = archive ? Helpdesk::ArchiveTicket.table_name : Helpdesk::Ticket.table_name
    time_sheet_group_to_column_map = {
      :customer_name => "IFNULL(#{archive ? Helpdesk::ArchiveTicket.table_name : Helpdesk::Ticket.table_name}.owner_id, #{archive ? Helpdesk::ArchiveTicket.table_name : Helpdesk::Ticket.table_name}.requester_id) as #{ALIAS_GROUP_NAME[group]}",
      :agent_name    => "#{Helpdesk::TimeSheet.table_name}.user_id",
      :group_name    => "#{archive ? Helpdesk::ArchiveTicket.table_name : Helpdesk::Ticket.table_name}.group_id",
      :product_name  => "#{archive ? Helpdesk::ArchiveTicket.table_name : Helpdesk::SchemaLessTicket.table_name}.product_id",
      :workable      => "#{archive ? Helpdesk::ArchiveTicket.table_name : Helpdesk::Ticket.table_name}.display_id",
      :group_by_day_criteria => "#{Helpdesk::TimeSheet.table_name}.executed_at as executed_at"
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
        (CASE WHEN #{group_by_caluse==:customer_name} THEN IFNULL(archive_tickets.owner_id,archive_tickets.requester_id)
             ELSE #{GROUP_TO_FIELD_MAP[group_by_caluse]} END) AS #{ALIAS_GROUP_NAME[group_by_caluse]}"
      ).group("#{ALIAS_GROUP_NAME[group_by_caluse]}, current, billable").find(:all, :conditions => (archive_select_conditions || {}),
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
         (CASE WHEN #{group_by_caluse==:customer_name} THEN IFNULL(helpdesk_tickets.owner_id,helpdesk_tickets.requester_id)
             ELSE #{GROUP_TO_FIELD_MAP[group_by_caluse]} END) AS #{ALIAS_GROUP_NAME[group_by_caluse]}").group("#{ALIAS_GROUP_NAME[group_by_caluse]}, current, billable").find(:all, :conditions => (select_conditions || {}),
                                                                                                                                                                       :include => [:user, :workable => [:schema_less_ticket, :group, :ticket_status, :requester, :company]])
    end
  end

  def fetch_timesheet_entries(offset=0, row_limit=nil)
    row_limit ||= @pdf_export ? BATCH_LIMIT_FOR_EXPORT : TIMESHEET_ROWS_LIMIT
    entries = scoper(@start_date, @end_date).where("helpdesk_time_sheets.id <= #{@latest_timesheet_id}").select("helpdesk_time_sheets.*, #{construct_custom_column_select_statement}  #{group_to_column_map(group_by_caluse, false)}").reorder("#{ALIAS_GROUP_NAME[group_by_caluse]}, id asc").find(:all, :limit => row_limit, :offset => offset,:conditions => (select_conditions || {}),
                                                                                                                                                                                                                                                                                                    :include => [:user, :workable => [{:schema_less_ticket => :product}, :group, :ticket_status, :requester, :company]])
    if (archive_enabled? && entries.size < row_limit )
      entries << archive_scoper(@start_date, @end_date).where("helpdesk_time_sheets.id <= #{@latest_timesheet_id}").select("helpdesk_time_sheets.*,  #{group_to_column_map(group_by_caluse, true)}").reorder("#{ALIAS_GROUP_NAME[group_by_caluse]}, id asc").find(:all, :limit => row_limit, :offset => offset,:conditions => (archive_select_conditions || {}),                                                                                                                                                                                                                                                                 :include => [:user, :workable => [:product, :group, :ticket_status, :requester, :company]])
    end
    entries.flatten
  end

  def time_sheet_list
    return if @filter_err.present?
    if params[:scroll_position]
      construct_timesheet_entries
    else
      @report_date = params[:date_range]
      @load_time = Time.now.utc
      @summary = fetch_summary
      @summary << fetch_summary(true) if archive_enabled?
      construct_timesheet_metric_data
      stacked_chart_data
      @time_sheets = @latest_timesheet_id ? timesheet_entries(0, TIMESHEET_ROWS_LIMIT) : {}
      @ajax_params = {scroll_position: 1, row_count: TIMESHEET_ROWS_LIMIT, group_by: group_by_caluse.to_s}
    end
  end

  def time_sheet_list_pdf
    @load_time = Time.now.utc
    @report_date = params[:date_range]
    @summary = fetch_summary
    @summary << fetch_summary(true) if archive_enabled?
    construct_timesheet_metric_data
    stacked_chart_data
    @time_sheets = @latest_timesheet_id ? timesheet_entries : {}
    return if @time_sheets.empty?
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
    return if @filter_err.present?
    @load_time = Time.now.utc
    @time_sheets = csv_filter(@start_date,@end_date)
    if archive_enabled?
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
    archive_scoper(start_date,end_date).select(" #{construct_custom_column_select_statement} helpdesk_time_sheets.*   ").find_in_batches(:batch_size => BATCH_LIMIT_FOR_EXPORT, :conditions => (archive_select_conditions || {}),
    :include => [:user, :workable => [:product, :group, :ticket_status, :requester, :company]]) do |time_sheets_batch|# need to ensure - Hari
      time_sheets_archive << time_sheets_batch
    end
    time_sheets_archive.flatten
  end

  def archive_select_conditions
    conditions = {}
    conditions[:ticket_type] = @ticket_type unless @ticket_type.empty?
    conditions[:priority] = @priority unless @priority.empty?
    conditions[:status] = @status unless @status.empty?
    conditions[:source] = @source unless @source.empty?
    {:archive_tickets => conditions} unless conditions.blank?
  end

  #used for index action to load the pick list
  #retuns an array for hash containing symbol, label and default value.
  def report_columns_hash
    report_columns_arr = []
    Helpdesk::TimeSheet.report_list.each do |key , value|
      if key == :product_name
        report_columns_arr.push({name:value, id: key, default: true, is_custom: false})  if Account.current.products.any?
      elsif key== [:agent_name]
        report_columns_arr.push({name:value, id: key, default: true , is_custom: false})  if Account.current.hide_agent_metrics_feature?
      else
        report_columns_arr.push({name:value,id: key, default: true, is_custom: false})
      end
    end

    #phase1 - adding only custom dropdown and nested fields.
    OPTIONAL_COLUMN_CONFIG.each do |key,value|
      report_columns_arr.push({name:value, id:key, default: false, is_custom: false})
    end
    Account.current.flexifield_def_entries.includes(:ticket_field).drop_down_fields.each do | flexifieldDefEntry|
      if flexifieldDefEntry.ticket_field
        report_columns_arr.push({name: flexifieldDefEntry.ticket_field.label_in_portal, id:flexifieldDefEntry.flexifield_name, default: false, is_custom: true})
      end
    end
    @report_columns = report_columns_arr
  end


  def custom_column_master_hash
    flexifields_hash = {}
    Account.current.flexifield_def_entries.includes(:ticket_field).drop_down_fields.each do | flexifieldDefEntry|
      if flexifieldDefEntry.ticket_field
        flexifields_hash[flexifieldDefEntry.flexifield_name.to_sym] = flexifieldDefEntry.ticket_field.label_in_portal
      end
    end
    flexifields_hash
  end


  def construct_time_entries_list
    result_time_sheets = {}
    str_header_keys_time_entry = @headers.map(&:to_s)
    str_header_keys_time_entry +=  ["timespent","billable","user_id","ticket_id","customer_id","product_id","group_id","display_id","subject","executed_at"]

    @time_sheets.each do | group_by_key, group_by_value|
      result_arr = []
      group_by_value.each do |time_entry|
        result_hash = time_entry.as_json[:time_entry].slice(*str_header_keys_time_entry)
        ticket_json =time_entry.workable.as_json["helpdesk_ticket"].stringify_keys.slice(*str_header_keys_time_entry)
        ticket_json[:group_name] = time_entry.workable.group.name if time_entry.workable.group.present?
        result_hash.merge!(ticket_json)
        if Account.current.products.any?
          if time_entry.workable.respond_to?(:schema_less_ticket)
            product_hash = time_entry.workable.schema_less_ticket.product.as_json
            result_hash.merge!(product_hash) if product_hash.present?
          else
            product_hash = time_entry.workable.product.as_json
            result_hash.merge!(product_hash) if product_hash.present?
          end
        end
        result_arr.push(result_hash)
      end
      result_time_sheets[group_by_key] = result_arr
    end

    {
      previous_group_id: @current_group_id,
      ajax_params: @ajax_params,
      current_params: @current_params,
      time_sheets: result_time_sheets,
      locals: { colspan: @colspan,
                group_by: @current_group,
                times_spent: @group_count,
                totaltime: @group_count.values.sum,
                group_header: @ajax_params[:group_header],
                group_by: @ajax_params[:group_by],
                load_time: @load_time
                } ,
      headers: @headers
    }

  end


  #************************** Archive methods stop here *****************************#

  private

  def run_on_slave(&block)
    Sharding.run_on_slave(&block)
  end

  def validate_max_multi_selects
    (@report_filters || []).inject([]) do |errors, filter|
      value_count = filter["value"].split(',').length
      if value_count > MULTI_SELECT_LIMIT
        errors << "Multi select count exceeded for #{filter[0]}"
      end
      errors
    end
  end

  def validate_max_filters
    @filter_err = @report_filters.length > TICKET_FILTER_LIMIT ? t('helpdesk_reports.filter_limit_exceeded', count: TICKET_FILTER_LIMIT) : false
  end

  def validate_filters
    @report_filters = params[:report_filters] || params[:data_hash][:report_filters]
    error_list = []
    error_list << VALIDATIONS.inject([]) do |errors, func|
      errors << send(func)
    end
    error_list = error_list.flatten.uniq.compact.reject(&:blank?)
    if error_list.any?
      Rails.logger.info "INVALID REPORT PARAMS #{error_list}"
      @filter_err = escape_keys(error_list)
    end
  end

  def custom_filters_enabled?
    return Account.current.features?(:custom_timesheet)
  end

  def select_flexiconditions
    @flexi_conditions = {}
    params[:report_filters].each do |filter|
      if filter[:condition].to_s.start_with?('ffs')
        name = filter[:condition]
        key = "@#{name}"
        val = instance_variable_get(key)
        @flexi_conditions[name] = val unless val.empty?
      end
    end
  end

  def select_conditions
    conditions = {}
    conditions[:ticket_type] = @ticket_type unless @ticket_type.empty?
    conditions[:priority] = @priority unless @priority.empty?
    conditions[:status] = @status unless @status.empty?
    conditions[:source] = @source unless @source.empty?
    {:helpdesk_tickets => conditions} unless conditions.blank?
  end

  def set_selected_tab
    @selected_tab = :reports
  end

  def set_report_type
    @report_type         = :timesheet_reports
    @user_time_zone_abbr = Time.zone.now.zone
  end

  def column_id_label_hash
    labels = {}
    @show_options.each do|id, field|
      labels[id] = field[:name]
      if field[:nested_fields]
        field[:nested_fields].each{|n_field| labels[n_field[:condition]] = n_field[:name]}
      end
    end
    labels
  end

  def construct_csv_params
    filters = params["filters"].to_s
    filters_hash = JSON.parse filters.gsub('=>', ':')
    data_hash = filters_hash["data_hash"]
    params[:report_filters] = data_hash["report_filters"]
    params[:columns] = data_hash["columns"]
    params[:version] = data_hash["version"]
    params[:date_range] = data_hash["date"]["date_range"]
  end

  def old_report_params params
    params[:data_hash].symbolize_keys!
    params[:data_hash][:report_filters].each do |filter|
      condition = filter['condition'] || filter['name']
      if((condition.to_s.start_with?('ffs') || condition.to_s == "ticket_type") && params[:version].present?)
        params[:"#{condition}"] = filter['label']
      else
        params[:"#{condition}"] = filter['value']
        params[:"#{condition}"] = params[:"#{condition}"].split(',') if filter['value'].is_a? Array
      end
    end
    params[:select_hash] = params[:data_hash][:select_hash]
    params[:date_range] ||= params[:data_hash][:date]['date_range'] #temporary. date range for direct export.
    params[:report_filters] = params[:data_hash][:report_filters]
    params[:version] ||= params[:data_hash][:version]
    params
  end

  def construct_custom_column_select_statement
    cols = @request_custom_fields_columns.collect { |col| ' flexifields.'+col+','}
    cols.join
  end

  def build_item
    show_options(DEFAULT_COLUMNS_ORDER, DEFAULT_COLUMNS_KEYS_BY_TOKEN, DEFAULT_COLUMNS_OPTIONS)
    @show_options[:billable] = {:is_in=>:dropdown, :condition=>:billable, :name=>"Billable",
                                :container=>"multi_select", :operator=>:is_in,
                                :options=>[[0, "Non-Billable"], [1, "Billable"]],
                                :value=>"", :field_type=>"default", :ff_name=>"default",
                                :active=>false
                                }
    @show_options.delete(:historic_status)
    @show_options.map { |filter| (@custom_filter ||= []) << filter[1][:condition].to_s if filter[0].to_s.start_with?('ffs') }
    @label_hash = column_id_label_hash
    @filter_conditions = {}
    @time_sheet_columns = params[:columns] || []
    report_filter_request_params =  params[:report_filters]

    if params[:current_params].present?
      @time_sheet_columns = params[:current_params][:columns] || []
      report_filter_request_params =  params[:current_params][:report_filters].values if  params[:current_params][:report_filters].present?
      params[:version] = params[:current_params][:version] if params[:current_params][:version].present?
    end
    validate_chosen_custom_fields(@time_sheet_columns.select { |column| column.start_with?('ffs')})
    report_filter_request_params.each do |filter|
      if params[:version].present?
        if filter[:label].present?
          label = filter[:condition]+"_label"
          @filter_conditions[filter[:condition]] = filter[:value].split(',')
          @filter_conditions["#{label}"] = filter[:label]
        else
          @filter_conditions[filter[:condition]] = filter[:value].split(',')
        end
      else
        @filter_conditions[filter[:name]] = filter[:value].split(',')
      end
    end
    @filter_conditions = @filter_conditions.with_indifferent_access
    @filter_conditions[:user_id] =  @filter_conditions[:agent_id] if @filter_conditions[:agent_id]
    @current_params = {
      :start_date  => start_date,
      :end_date    => end_date,
      :customer_id => @filter_conditions[:customers] ? @filter_conditions[:customers] : [],
      :user_id     => (Account.current.hide_agent_metrics_feature? ? [] : (@filter_conditions[:user_id] || [])),
      :headers     => list_view_items,
      :billable    => billable_and_non? ? [true, false] : @filter_conditions[:billable].map {|val| val.to_bool},
      :group_id    => @filter_conditions[:group_id] || [],
      :ticket_type => @filter_conditions[:ticket_type_label] || @filter_conditions[:ticket_type] || [],
      :products_id => @filter_conditions[:product_id]|| [],
      :priority    => @filter_conditions[:priority] || [],
      :status      => @filter_conditions[:status] || [],
      :source      => @filter_conditions[:source] || [],
      :report_filters => report_filter_request_params || [],
      :group_by    => group_by_caluse,
      :columns    => @time_sheet_columns,

    }
    @current_params[:version] = params[:version] if params[:version].present?
    report_filter_request_params.each do |filter|
      if filter[:condition].to_s.start_with?('ffs')
        val = "#{filter[:condition]}"+"_label"
        @current_params[filter[:condition]] = @filter_conditions["#{val}"] || []
      end
    end
    @current_params.each{ |name, value| instance_variable_set("@#{name}", value) }

  end

  def billable_and_non?
    @filter_conditions[:billable].blank? or (@filter_conditions[:billable].include?("true") and  @filter_conditions[:billable].include?("false"))
  end

  def group_by_caluse
    @group_by_field ||= construct_group_by_caluse
  end

  def construct_group_by_caluse
    group_by_caluse = @filter_conditions[:group_by] || @filter_conditions[:group_by_field] || :customer_name
    group_by_caluse = group_by_caluse.first if group_by_caluse.is_a? Array
    group_by_caluse = group_by_caluse.to_sym()
    params[:group_by] = group_by_caluse
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
        hash_key = entry.send(ALIAS_GROUP_NAME[group_by_caluse]) || 0
        hash_key = hash_key.beginning_of_day if(group_by_caluse==:group_by_day_criteria)
        @group_count[hash_key] += (entry.time_spent || 0)
        if @group_names[hash_key].blank?
          if group_by_caluse == :workable
            @group_names[hash_key] = "#{entry.send(group_by_caluse).subject} (##{entry.send(group_by_caluse).display_id})".gsub(/`|"/, " ")
          elsif group_by_caluse == :group_by_day_criteria
            @group_names[hash_key] = hash_key
          else
            @group_names[hash_key] = entry.send(group_by_caluse).gsub(/`|"/, " ")
          end
        end
      end
    end
    [:total_time, :billable, :non_billable].each do |type|
      @metric_data[:previous][type] /= 3600.0
      @metric_data[:current][type] /= 3600.0
    end
    @latest_timesheet_id = @summary.flatten.collect{ |entry| entry.max_timesheet_id if entry.current == 1}.compact.max
    total_time = 0
    group_count_in_hrs = @group_count.collect do |k,v|
      total_time += v
      [k, get_time_in_hours(v)]
    end
    @total_time = get_time_in_hours(total_time)
    @group_count = Hash[ group_count_in_hrs ]
  end

  def timesheet_entries(offset=0, row_limit=nil)
    #To handle initial page load case
    entries = fetch_timesheet_entries(offset, row_limit)
    result = {}
    entries.each do |entry|
      hash_key = entry.send(ALIAS_GROUP_NAME[group_by_caluse]) || 0
      hash_key = hash_key.beginning_of_day if(group_by_caluse==:group_by_day_criteria)
      result[hash_key] ||= []
      result[hash_key] << entry
    end
    result
  end

  def construct_timesheet_entries
    params[:current_params].each { |name, value| instance_variable_set("@#{name}", (value || [])) }
    @billable.map!{|b| b.to_bool} if @billable
    offset = params[:scroll_position].to_i * TIMESHEET_ROWS_LIMIT
    @current_group = [group_by_caluse]
    [:totaltime, :group_names, :latest_timesheet_id].each { |param| instance_variable_set("@#{param}", params[param])}
    @load_time = Time.parse("#{params[:load_time]}")
    @time_sheets = timesheet_entries(offset)
    @time_sheets.stringify_keys!
    @group_count = params[:group_count]
    unless @time_sheets.empty?
      @current_group_id = @time_sheets.keys.last
    end
    @headers = list_view_items
    @colspan = @headers.length-1
    @ajax_params = {scroll_position: params[:scroll_position], row_count: offset, group_by: [group_by_caluse], group_header: params[:previous_group_id]}
    @current_params = params[:current_params]
  end

  #archive tickets will be included only if custom columns / custom filters aren't applied
  def archive_enabled?
    @archive_enabled ||= Account.current.features_included?(:archive_tickets) && @flexi_conditions.empty? && @request_custom_fields_columns.empty?
  end

  def get_time_in_hours(seconds)
    hh = (seconds/3600).to_i
    mm = ((seconds % 3600)/60.to_f).round

    hh.to_s.rjust(2,'0') + ":" + mm.to_s.rjust(2,'0')
  end

  def validate_chosen_custom_fields(cols)
    @request_custom_fields_columns =  cols & custom_column_master_hash.stringify_keys.keys
  end

end
