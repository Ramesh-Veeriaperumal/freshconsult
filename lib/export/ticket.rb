class Export::Ticket < Struct.new(:export_params)
  include Helpdesk::Ticketfields::TicketStatus
  include ExportCsvUtil
  include Rails.application.routes.url_helpers
  include Export::Util
  include Redis::RedisKeys
  include Helpdesk::TicketModelExtension
  
  DATE_TIME_PARSE = [ :created_at, :due_by, :resolved_at, :updated_at, :first_response_time, :closed_at]

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
        DataExportMailer.send_later(:ticket_export, {
                                                      :user => User.current, 
                                                      :domain => export_params[:portal_url],
                                                      :url => hash_url(export_params[:portal_url]),
                                                      :export_params => export_params
                                                    })
      end
    rescue => e
      NewRelic::Agent.notice_error(e)
      puts "Error  ::#{e.message}\n#{e.backtrace.join("\n")}"
      @data_export.failure!(e.message + "\n" + e.backtrace.join("\n"))
    end
  end

  def self.enqueue(export_params)
    # Not using the methods in RedisOthers to avoid the include /extend problem
    # class methods vs instance methods issue
    export_params = export_params.except(:authenticity_token, :action, :controller, :utf8)
    if $redis_others.perform_redis_op("exists", TICKET_EXPORT_SIDEKIQ_ENABLED)
      if $redis_others.perform_redis_op("sismember", PREMIUM_TICKET_EXPORT, Account.current.id)
        Tickets::Export::PremiumTicketsExport.perform_async(export_params)
      elsif $redis_others.perform_redis_op("sismember", LONG_RUNNING_TICKET_EXPORT, Account.current.id)
        Tickets::Export::LongRunningTicketsExport.perform_async(export_params)
      else
        Tickets::Export::TicketsExport.perform_async(export_params)
      end
    else
      Resque.enqueue(Helpdesk::TicketsExport, export_params)
    end
  end
  
  protected

  def initialize_params
    export_params.symbolize_keys!
    file_formats = ['csv', 'xls']
    reorder_export_params
    export_params[:format] = file_formats[0] unless file_formats.include? export_params[:format]
    delete_invisible_fields
  end

  def set_current_user
    unless User.current 
      user = Account.current.users.find(export_params[:current_user_id])
      user.make_current
    end
    TimeZone.set_time_zone
  end

  def export_file
    send("#{export_params[:format]}_export")
  end

  def csv_export
    csv_hash = export_params[:export_fields]
    csv_string = CSVBridge.generate do |csv|
      csv_headers = @headers.collect {|header| csv_hash[header]}
      csv << csv_headers
      ticket_data(csv)
    end
    csv_string 
  end

  def xls_export
    require 'erb'
    @xls_hash = export_params[:export_fields]
    ticket_data
    path =  "#{Rails.root}/app/views/support/tickets/export_csv.xls.erb"
    ERB.new(File.read(path)).result(binding)
  end

  def ticket_data(records=[])
    @no_tickets = true
    # Initializing for CSV with Record headers.
    @records = records

    if export_params[:archived_tickets]
      Account.current.archive_tickets.permissible(User.current).find_in_batches(archive_export_query) do |items|
        add_to_records(items)  
      end
    else
      Account.current.tickets.permissible(User.current).find_in_batches(export_query) do |items|
        add_to_records(items)  
      end
    end
  end

  def export_query
    {
      :select => select_query,
      :conditions => sql_conditions, 
      :joins => joins
    }
  end

  def add_to_records(items)
    @no_tickets = false
    @custom_field_names = Account.current.ticket_fields.custom_fields.pluck(:name)
    date_format = Account.current.date_type(:short_day_separated)
    ActiveRecord::Associations::Preloader.new(items, preload_associations).run

    items.each do |item|
      record = []
      @headers.each do |val|
        begin
          data = export_params[:archived_tickets] ? fetch_field_value(item, val) : item.send(val)
          if data.present?
            if DATE_TIME_PARSE.include?(val.to_sym)
              data = parse_date(data)
            elsif @custom_field_names.include?(val) && data.is_a?(Time)
              data = data.utc.strftime(date_format)
            end
          end
          record << escape_html(strip_equal(data))
        rescue Exception => e
          NewRelic::Agent.notice_error(e,{:custom_params => {:ticket_id => item.id }})
          Rails.logger.info "Exception in tickets export::: Ticket:: #{item}, data:: #{data}"
        end
      end
      @records << record
    end
  end

  def preload_associations
    associations = []
    @headers.each do |val|
      if val.eql?("product_name")
        associations << { :schema_less_ticket => :product }
      elsif @custom_field_names.include?(val)
        associations << { :flexifield => { :flexifield_def => :flexifield_def_entries } }
      elsif Helpdesk::TicketModelExtension::ASSOCIATION_BY_VALUE[val]
        associations << Helpdesk::TicketModelExtension::ASSOCIATION_BY_VALUE[val]
      end
    end
    associations.uniq
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
    @headers = export_params[:export_fields].keys
    @headers.delete_if{|header_key|
      !allowed_fields.include?(header_key)
    }
  end

  def parse_date(date_time)
    if date_time.class == String
      DateTime.parse(date_time).strftime("%F %T")
    else
      date_time.strftime("%F %T")
    end
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
    DataExportMailer.send_later(:no_tickets, {
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

  def reorder_export_params
    export_fields = export_params[:export_fields]
    return if export_fields.blank?
    ticket_fields   = default_export_fields_order.merge(custom_export_fields_order)

    param_position_hash = export_fields.keys.inject({}) do |hash, key|
      hash[key] = ticket_fields[key]      
      hash
    end
    sorted_param_list = param_position_hash.sort_by{|k,v| v}

    sorted_export_fields = sorted_param_list.inject({}) do |hash, element|
      hash[element[0]] = export_fields[element[0]]
      hash
    end 
    export_params[:export_fields] = sorted_export_fields
  end

end