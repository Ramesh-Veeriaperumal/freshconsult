class Helpdesk::TicketsExportWorker < Struct.new(:export_params)
  include Helpdesk::Ticketfields::TicketStatus
  include ActionController::UrlWriter
  DATE_TIME_PARSE = [ :created_at, :due_by, :resolved_at, :updated_at, :first_response_time, :closed_at]

  def perform
    begin
      initialize_params
      set_current_user
      check_and_create_ticket_export
      file_string =  Sharding.run_on_slave{ export_file }
      if @no_tickets 
        send_no_ticket_email
      else
        build_file(file_string) 
        DataExportMailer.deliver_ticket_export({:user => User.current, 
                                                :domain => Account.current.full_domain, 
                                                :url => hash_url})
      end
    rescue => e
      NewRelic::Agent.notice_error(e)
      puts "Error  ::#{e.message}\n#{e.backtrace.join("\n")}"
      @item.failure!(e.message + "\n" + e.backtrace.join("\n"))
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

  def check_and_create_ticket_export
    limit_data_exports
    @item = Account.current.data_exports.new(
                                      :source => DataExport::EXPORT_TYPE[:ticket], 
                                      :user => User.current,
                                      :status => DataExport::EXPORT_STATUS[:started]
                                    )
    @item.save
  end

  def limit_data_exports
    acc_ticket_export = User.current.data_exports.ticket_export
    acc_ticket_export.first.destroy if acc_ticket_export.count >= DataExport::TICKET_EXPORT_LIMIT
  end

  def export_file
    send("#{export_params[:format]}_export")
  end

  def csv_export
    csv_hash = export_params[:export_fields]
    record_headers = csv_hash.keys.sort
    csv_string = CSVBridge.generate do |csv|
      csv_headers = record_headers.collect {|header| csv_hash[header]}
      csv << csv_headers
      ticket_data(csv)
    end
    csv_string 
  end

  def xls_export
    require 'erb'
    @xls_hash = export_params[:export_fields] 
    @headers = @xls_hash.keys.sort
    @records = ticket_data
    path =  "#{RAILS_ROOT}/app/views/support/tickets/export_csv.xls.erb"
    ERB.new(File.read(path)).result(binding)
  end

  def ticket_data(records=[])
    @no_tickets = true
    # Initializing for CSV with Record headers.
    @records = records
    headers = export_params[:export_fields].keys.sort
    Account.current.tickets.find_in_batches(export_query) do |items|
      add_to_records(headers, items)  
    end
    @records
  end

  def export_query
    {
      :select => select_query,
      :conditions => sql_conditions, 
      :include => [:ticket_states, :ticket_status, :flexifield, :responder, :requester],
      :joins => joins
    }
  end

  def add_to_records(headers, items)
    @no_tickets = false
    @records ||= []
    items.each do |item|
      record = []
      headers.each do |val|
        data = item.send(val)
        data = parse_date(data) if DATE_TIME_PARSE.include?(val.to_sym) and data.present?
        record << escape_html(data)
      end
      @records << record
    end
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

  def build_file file_string
    write_file(file_string)
    @item.file_created!
    build_attachment(file_path)
    remove_export_file(file_path)
  end

  def write_file file_string
    File.open(file_path , "wb") do |f|
      f.write(file_string)
    end
  end

  def file_path
    @file_path ||= begin
      output_dir = "#{RAILS_ROOT}/tmp" 
      FileUtils.mkdir_p output_dir
      file_path = "#{output_dir}/#{file_name}"
      file_path
    end
  end

  def file_name
    "ticket_export.#{export_params[:format]}"
  end

  def escape_html(val)
    ((val.blank? || val.is_a?(Integer)) ? val : CGI::unescapeHTML(val.to_s).gsub(/\s+/, " "))
  end
  
  def remove_export_file(file_path)
    # FileUtils.rm_f(file_path)
    @item.completed!
  end

  def build_attachment(file_path)
    file = File.open(file_path,  'r')
    attachment = @item.build_attachment(:content => file,  :account_id => Account.current.id)
    attachment.save!
    @item.file_uploaded!
  end

  def hash(export_id)
    hash = Digest::SHA1.hexdigest("#{export_id}#{Time.now.to_f}")
    @item.save_hash!(hash)
    hash
  end

  def hash_url
    url_for(
            :controller => "download_file/#{@item.source}/#{hash(@item.id)}", 
            :host => Account.current.full_domain, 
            :protocol => 'https'
            )
  end

  def send_no_ticket_email
    DataExportMailer.deliver_no_tickets({
                                          :user => User.current,
                                          :domain => Account.current.full_domain
                                        })
    @item.destroy
  end

end