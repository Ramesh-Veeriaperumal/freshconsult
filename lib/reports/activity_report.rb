module Reports::ActivityReport
  
  def fetch_activity
    columns_in_use = columns
    unless params[:reports].nil?
      columns_in_use = columns_in_use.concat(params[:reports])
    end
  
    columns_in_use.each do |column_name|
      tickets_count = group_tkts_by_columns({:column_name => column_name })
      tickets_hash = get_tickets_hash(tickets_count,column_name)
      self.instance_variable_set("@#{column_name.to_s.gsub('.', '_')}_hash", tickets_hash)
    end
  end
  
 def get_tickets_time_line
    timeline_columns.each do |column|
      ticket_timeline = group_tkts_by_timeline(column)
      self.instance_variable_set("@#{column}_hash", ticket_timeline)
    end
    gen_line_chart(@created_at_hash,@resolved_at_hash)
  end
  
  def timeline_date_condition(type)
    " (helpdesk_ticket_states.#{type} > '#{start_date}' and helpdesk_ticket_states.#{type} < '#{end_date}' )"
  end
  
  def add_resolved_and_closed_tickets(hash)
    hash.fetch(TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved],{}).fetch(:count,0).to_i + hash.fetch(TicketConstants::STATUS_KEYS_BY_TOKEN[:closed],{}).fetch(:count,0).to_i
  end
  
  def get_tickets_hash(tickets_count,column_name)
    tot_count = 0
    tickets_hash = {}
    tickets_count.each do |ticket|
      tot_count += ticket.count.to_i
      if column_name.to_s.starts_with?('flexifields.')
        tickets_hash.store(ticket.send(column_name.gsub('flexifields.','')),{:count => ticket.count})
      else
        tickets_hash.store(ticket.send(column_name),{:count => ticket.count})
      end

    end
    tickets_hash.store(TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved],{ :count =>  add_resolved_and_closed_tickets(tickets_hash)}) if column_name.to_s == "status"
    @current_month_tot_tickets = tot_count
    tickets_hash = calculate_percentage_for_columns(tickets_hash,@current_month_tot_tickets)
    
    case column_name.to_s
      when "source"
        gen_single_stacked_bar_chart(tickets_hash, column_name)
      else
        @pie_charts_hash[column_name] = gen_pie_chart(tickets_hash,column_name) unless columns.include?(column_name)
    end
    
    tickets_hash
  end

  def calculate_percentage_for_columns(tickets_hash,tkts_count)
    new_val_hash = {}
    unless tickets_hash.empty?
     tickets_hash.each do |key,val_hash|
       val_per  = (val_hash.fetch(:count).to_f/tkts_count.to_f) * 100
       val_hash.store(:percentage,sprintf( "%0.02f", val_per))
       new_val_hash.store(key,val_hash)
     end
   end
   new_val_hash
 end
 
 def calculate_resolved_on_time
     @avg_sla_current_month = 0
     resolved_count = count_of_resolved_on_time
     if !@current_month_tot_tickets.nil? and @current_month_tot_tickets > 0
       @avg_sla_current_month = (resolved_count.to_f/@current_month_tot_tickets.to_f) * 100
     end
     last_month_resolved_count = last_month_count_of_resolved_on_time
     last_month_tot_tickets = count_of_tickets_last_month
     if !last_month_tot_tickets.nil? and last_month_tot_tickets != 0
       avg_sla_last_month = (last_month_resolved_count.to_f/last_month_tot_tickets.to_f) * 100
     end
     if !avg_sla_last_month.nil? and !@avg_sla_current_month.nil?
       @sla_diff = @avg_sla_current_month - avg_sla_last_month
     end

     gen_pie_gauge(@avg_sla_current_month,"sla")
  end
  
  def calculate_fcr
     @avg_fcr_month = 0
     fcr_count = count_of_fcr
     if !@current_month_tot_tickets.nil? and @current_month_tot_tickets > 0
       @avg_fcr_month = (fcr_count.to_f/@current_month_tot_tickets.to_f) * 100
     end
     last_month_fcr_count = last_month_count_of_fcr
     last_month_tot_tickets = count_of_tickets_last_month
     if !last_month_tot_tickets.nil? and last_month_tot_tickets != 0
       avg_last_month = (last_month_fcr_count.to_f/last_month_tot_tickets.to_f) * 100
     end
     if !avg_last_month.nil? and !@avg_fcr_month.nil?
       @fcr_diff = @avg_fcr_month - avg_last_month
     end
     gen_pie_gauge(@avg_fcr_month,"fcr")
  end
 
  def scoper(starting_time = start_date, ending_time = end_date)
    Account.current.tickets.visible.created_at_inside(starting_time,ending_time)
  end
  
  def start_date
    parse_from_date.nil? ? 30.days.ago.to_s(:db): Time.parse(parse_from_date).beginning_of_day.to_s(:db) 
  end
  
  def end_date
    parse_to_date.nil? ? Time.now.to_s(:db): Time.parse(parse_to_date).end_of_day.to_s(:db)
  end
  
  def parse_from_date
    (params[:date_range].split(" - ")[0]) || params[:date_range]
  end
  
  def parse_to_date
    (params[:date_range].split(" - ")[1]) || params[:date_range]
  end
  
  def previous_start
    distance_between_dates =  Time.parse(end_date) - Time.parse(start_date)
    prev_start = Time.parse(previous_end) - distance_between_dates
    prev_start.beginning_of_day.to_s(:db)
  end
  
  def previous_end
    (Time.parse(start_date) - 1.day).end_of_day.to_s(:db)
  end
  
  def write_io
    current_index = 0
    io = StringIO.new('')
    book = Spreadsheet::Workbook.new
    sheet = book.create_worksheet
    sheet.name = 'Activity Report'
    row = sheet.row(current_index)
    columns_in_use = columns
    unless params[:reports].nil?
      columns_in_use = columns_in_use.concat(params[:reports])
      columns_in_use.each do  |column_name|
        current_index = fill_row(self.instance_variable_get("@#{column_name.to_s.gsub('.', '_')}_hash"),sheet,column_name,current_index)
      end
    end
    unless @current_month_tot_tickets == 0 
      export_line_chart_data(sheet,current_index)      
    end
    book.write(io)
    io.string
  end
  
  def export_line_chart_data(sheet,current_index)
    row = sheet.row(current_index+=2)
      row.push("Date","Created Count","Resolved Count")
      data_series_hash = {}
      unless @created_at_hash.nil?
        @created_at_hash.each do |tkt|
          data_series_hash.store(tkt.date,{:created_count => tkt.count.to_i})
        end
      end
      unless @resolved_at_hash.nil?
        @resolved_at_hash.each do |tkt|
          data_series_hash.store(tkt.date,(data_series_hash.fetch(tkt.date,{:created_count => 0})).merge({:resolved_count,tkt.count.to_i}))
        end
      end
      data_series_hash.each do |date,count_hash|
        row = sheet.row(current_index+=1)
        row.push(date,count_hash.fetch(:created_count,0),count_hash.fetch(:resolved_count,0))
    end
  end
  
  def fill_row(column_hash,sheet,column_name,current_index)
    row = sheet.row(current_index+=2)
    row.push("Tickets By #{@pie_chart_labels.fetch(column_name,column_name)}")
    constants_mapping = Reports::ChartGenerator::TICKET_COLUMN_MAPPING.fetch(column_name.to_s,column_hash)
    if column_name.eql?(:status)
      constants_mapping = TicketConstants::STATUS_NAMES_BY_KEY.clone()
      constants_mapping.delete(TicketConstants::STATUS_KEYS_BY_TOKEN[:closed]) 
    end
    constants_mapping.each do |k,v|
      row = sheet.row(current_index+=1)
      label = Reports::ChartGenerator::TICKET_COLUMN_MAPPING.has_key?(column_name.to_s) ? v : k
      row.push(label,column_hash.fetch(k,{}).fetch(:count,0).to_i)
    end
    current_index
  end
  
end