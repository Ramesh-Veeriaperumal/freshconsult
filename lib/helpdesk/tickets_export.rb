class Helpdesk::TicketsExport 
  extend Resque::AroundPerform
  include Helpdesk::Ticketfields::TicketStatus
  @queue = 'ticketsExportQueue'

  def self.perform(export_params)

    Sharding.run_on_slave do
      export_params.symbolize_keys!
      user = Account.current.users.find(export_params[:current_user_id])
      user.make_current
      TimeZone.set_time_zone
      #Need to be removed - kiran 
      if export_params[:data_hash]
        json_conditions = []
        json_conditions = ActiveSupport::JSON.decode(export_params[:data_hash]) if export_params[:data_hash].length > 2 and !export_params[:data_hash].is_a?(Array)
        json_conditions.delete_if {|condition_hash| condition_hash["condition"] == "created_at"}
        export_params[:data_hash] = json_conditions
      end
      #####
      index_filter =  Account.current.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME).deserialize_from_params(export_params)
      @sql_conditions = index_filter.sql_conditions
      @sql_conditions[0].concat(%(and helpdesk_ticket_states.#{export_params[:ticket_state_filter]} 
                                 between '#{export_params[:start_date]}' and '#{export_params[:end_date]}'
                                )
                              )

      @sql_conditions[0].concat(%(and helpdesk_tickets.status in (#{RESOLVED}, #{CLOSED}))
                              ) if export_params[:ticket_state_filter].eql?("resolved_at")
      @sql_conditions[0].concat(%(and helpdesk_tickets.status in (#{CLOSED}))
                              ) if export_params[:ticket_state_filter].eql?("closed_at")

      @all_joins = index_filter.get_joins(@sql_conditions)
      @all_joins[0].concat(%( INNER JOIN helpdesk_ticket_states ON 
                     helpdesk_ticket_states.ticket_id = helpdesk_tickets.id AND 
                     helpdesk_tickets.account_id = helpdesk_ticket_states.account_id))
      @select = "helpdesk_tickets.* "
      @select = "DISTINCT(helpdesk_tickets.id) as 'unique_id' , #{@select}" if @sql_conditions[0].include?("helpdesk_tags.name")
      export_params[:format] == 'csv' ?  csv_export(export_params) : xls_export(export_params)
    end
  end

  def self.escape_html(val)
    ((val.blank? || val.is_a?(Integer)) ? val : CGI::unescapeHTML(val.to_s).gsub(/\s+/, " "))
  end

  def self.ticket_data(export_params, records=[])
    export_fields = export_params[:export_fields]
    headers = export_fields.keys.sort
    Account.current.tickets.find_in_batches(:select => @select,
                                    :conditions => @sql_conditions, 
                                      :include => [:ticket_states, :ticket_status, :flexifield,
                                                   :responder, :requester],
                                      :joins => @all_joins
                                     ) do |items|
        items.each do |item|
        record = []
        headers.each do |val|
          data = item.send(val)
          record << escape_html(data)
        end
        records << record
      end
    end
    records
  end


  def self.csv_export export_params
    csv_hash = export_params[:export_fields]
    record_headers = csv_hash.keys.sort
    csv_string = CSVBridge.generate(:col_sep => "\t") do |csv|
      csv_headers = record_headers.collect {|header| csv_hash[header]}
      csv << csv_headers
      ticket_data(export_params,csv)
    end 
    Rails.logger.info "<--- Triggering export tickets csv mail. User Email Id: #{User.current.email} --->"
    Rails.logger.info "<--- Params #{export_params[:ticket_state_filter]}, #{export_params[:start_date]}, #{export_params[:end_date]} --->"
    Helpdesk::TicketNotifier.deliver_export(export_params, csv_string, User.current)
  end

  def self.xls_export export_params
    require 'erb'
    @xls_hash = export_params[:export_fields] 
    @headers = @xls_hash.keys.sort
    @records = ticket_data(export_params)
    path =  "#{RAILS_ROOT}/app/views/support/tickets/export_csv.xls.erb"
    renderer = ERB.new(File.read(path))
    xls_string = renderer.result(binding)
    Helpdesk::TicketNotifier.deliver_export_xls(export_params, xls_string, User.current)
  end
end