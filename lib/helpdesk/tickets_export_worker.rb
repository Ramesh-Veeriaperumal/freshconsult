class Helpdesk::TicketsExportWorker < Struct.new(:export_params)
  include Helpdesk::Ticketfields::TicketStatus
  include ExportCsvUtil
  include Rails.application.routes.url_helpers
  include Export::Util
  DATE_TIME_PARSE = [ :created_at, :due_by, :resolved_at, :updated_at, :first_response_time, :closed_at]
  
  # Temporary workaround for '.' in values
  # Need to check and remove with better fix after Rails 3 migration
  PRELOAD_ASSOCIATIONS = [
                          { :flexifield => { 
                                              :flexifield_def => :flexifield_def_entries 
                                            }},
                          # { :requester => :user_emails },
                          # { :responder => :user_emails },
                          { :schema_less_ticket => :product }, 
                          :tags,
                          :ticket_old_body,
                          :ticket_states,
                          :ticket_status,
                          :time_sheets
                        ]

  PRELOAD_ARCHIVE_TICKET_ASSOCIATIONS = [
                          { :flexifield => { :flexifield_def => :flexifield_def_entries }},
                          # { :requester => :user_emails },
                          # { :responder => :user_emails },
                          :ticket_status,
                          :time_sheets
                        ]

  def perform
    begin
      initialize_params
      set_current_user
      check_and_create_export "ticket"
      file_string =  Sharding.run_on_slave{ export_file }
      if @no_tickets 
        send_no_ticket_email
      else
        build_file(file_string, "ticket", export_params[:format]) 
        DataExportMailer.ticket_export({:user => User.current, 
                                                :domain => export_params[:portal_url],
                                                :url => hash_url(export_params[:portal_url]),
                                                :export_params => export_params})
      end
    rescue => e
      NewRelic::Agent.notice_error(e)
      puts "Error  ::#{e.message}\n#{e.backtrace.join("\n")}"
      @data_export.failure!(e.message + "\n" + e.backtrace.join("\n"))
    end
  end

  protected

  def initialize_params
    export_params.symbolize_keys!
    file_formats = ['csv', 'xls']
    export_params[:format] = file_formats[0] unless file_formats.include? export_params[:format]
  end

  def set_current_user
    user = Account.current.users.find(export_params[:current_user_id])
    user.make_current
    TimeZone.set_time_zone
  end

  def export_file
    send("#{export_params[:format]}_export")
  end

  def csv_export
    csv_hash = export_params[:export_fields]
    record_headers = delete_invisible_fields
    csv_string = CSVBridge.generate do |csv|
      csv_headers = record_headers.collect {|header| csv_hash[header]}
      csv << csv_headers
      ticket_data(csv,record_headers)
    end
    csv_string 
  end

  def xls_export
    require 'erb'
    @xls_hash = export_params[:export_fields]
    @headers = delete_invisible_fields 
    @records = ticket_data(@headers)
    path =  "#{Rails.root}/app/views/support/tickets/export_csv.xls.erb"
    ERB.new(File.read(path)).result(binding)
  end

  def ticket_data(records=[],headers)
    @no_tickets = true
    # Initializing for CSV with Record headers.
    @records = records

    if export_params[:archived_tickets]
      Account.current.archive_tickets.permissible(User.current).find_in_batches(archive_export_query) do |items|
        add_to_records(headers, items)  
      end
    else
      Account.current.tickets.permissible(User.current).find_in_batches(export_query) do |items|
        add_to_records(headers, items)  
      end
    end
    @records
  end

  def export_query
    {
      :select => select_query,
      :conditions => sql_conditions, 
      :joins => joins
    }
  end

  def add_to_records(headers, items)
    @no_tickets = false
    @records ||= []
    custom_field_names = Account.current.ticket_fields.custom_fields.map(&:name)
    date_format = Account.current.date_type(:short_day_separated)

    # Temporary workaround for '.' in values
    # Need to check and remove with better fix after Rails 3 migration

    if export_params[:archived_tickets]
      ActiveRecord::Associations::Preloader.new(items, PRELOAD_ARCHIVE_TICKET_ASSOCIATIONS).run
    else
      ActiveRecord::Associations::Preloader.new(items, PRELOAD_ASSOCIATIONS).run
    end

    items.each do |item|
      record = []
      headers.each do |val|
        data = export_params[:archived_tickets] ? fetch_field_value(item, val) : item.send(val)
        if data.present?
          if DATE_TIME_PARSE.include?(val.to_sym)
            data = parse_date(data)
          elsif custom_field_names.include?(val) && data.is_a?(Time)
            data = data.utc.strftime(date_format)
          end
        end
        record << escape_html(data)
      end
      @records << record
    end
  end

  def fetch_field_value(item, field)
    item.respond_to?(field) ? item.send(field) : item.custom_field_value(field)
  end

  def allowed_fields
    @allowed_fields ||= begin
      (export_fields.collect do |key| 
        [key[:value]].concat( nested_fields_values(key) )
      end).flatten
    end
  end

  def nested_fields_values(key)
    return [] unless key[:type] == "nested_field"
    key[:levels].collect {|lvl| lvl[:name] }
  end

  def delete_invisible_fields
    headers = export_params[:export_fields].keys
    headers.delete_if{|header_key|
      !allowed_fields.include?(header_key)
    }
    headers
  end

  def parse_date(date_time)
    date_time.strftime("%F %T")
  end

  def sql_conditions
    @sql_conditions ||= begin
      @index_filter =  Account.current.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME).deserialize_from_params(export_params)
      sql_conditions = @index_filter.sql_conditions
      sql_conditions[0].concat(date_conditions)

      sql_conditions[0].concat(%(and helpdesk_tickets.status in (#{RESOLVED}, #{CLOSED}))
                              ) if export_params[:ticket_state_filter].eql?("resolved_at")
      sql_conditions[0].concat(%(and helpdesk_tickets.status in (#{CLOSED}))
                            ) if export_params[:ticket_state_filter].eql?("closed_at")
      sql_conditions
    end
  end

  def date_conditions
    %(and helpdesk_ticket_states.#{export_params[:ticket_state_filter]} 
       between '#{export_params[:start_date]}' and '#{export_params[:end_date]}'
      )
  end

  def select_query
    # sql_conditions
    select = "helpdesk_tickets.* "
    select = "DISTINCT(helpdesk_tickets.id) as 'unique_id' , #{select}" if sql_conditions[0].include?("helpdesk_tags.name")
    select
  end

  def joins
    all_joins = @index_filter.get_joins(sql_conditions)
    all_joins[0].concat(%( INNER JOIN helpdesk_ticket_states ON 
                   helpdesk_ticket_states.ticket_id = helpdesk_tickets.id AND 
                   helpdesk_tickets.account_id = helpdesk_ticket_states.account_id))
    all_joins        
  end

  def escape_html(val)
    ((val.blank? || val.is_a?(Integer)) ? val : CGI::unescapeHTML(val.to_s).gsub(/\s+/, " "))
  end

  def send_no_ticket_email
    DataExportMailer.no_tickets({
                                          :user => User.current,
                                          :domain => export_params[:portal_url]
                                        })
    @data_export.destroy
  end

  # Archive queries
  def archive_export_query
    {
      :select =>  archive_select_query,
      :conditions => archive_sql_conditions, 
      :joins => archive_joins
    }
  end

  def archive_select_query
    select = "archive_tickets.* "
    select = "DISTINCT(archive_tickets.id) as 'unique_id' , #{select}" if sql_conditions[0].include?("helpdesk_tags.name")
    select
  end

  def archive_sql_conditions    
    @index_filter = Helpdesk::Filters::ArchiveTicketFilter.new.deserialize_from_params(export_params)
    sql_conditions = @index_filter.sql_conditions
    sql_conditions[0].present? ? sql_conditions[0].concat("and #{archive_date_conditions}") : 
                              (sql_conditions = [archive_date_conditions])
    @sql_conditions = sql_conditions
  end

  def archive_joins
    @index_filter.get_joins(archive_sql_conditions)
  end

  def archive_date_conditions
    %(archive_tickets.#{export_params[:ticket_state_filter]} 
       between '#{export_params[:start_date]}' and '#{export_params[:end_date]}'
      )
  end

end