class Helpdesk::TicketsExport < Resque::FreshdeskBase
  include Helpdesk::Ticketfields::TicketStatus
  @queue = 'ticketsExportQueue'

  def self.perform(export_params)
    SeamlessDatabasePool.use_persistent_read_connection do
      export_params.symbolize_keys!
      #Need to be removed - kiran 
      if export_params[:data_hash]
        json_conditions = []
        json_conditions = ActiveSupport::JSON.decode(export_params[:data_hash]) if export_params[:data_hash].length > 2 and !export_params[:data_hash].is_a?(Array)
        json_conditions.delete_if {|condition_hash| condition_hash["condition"] == "created_at"}
        export_params[:data_hash] = json_conditions
      end
      #####
      index_filter =  Account.current.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME).deserialize_from_params(export_params)
      sql_conditions = index_filter.sql_conditions
      sql_conditions[0].concat(%(and helpdesk_ticket_states.#{export_params[:ticket_state_filter]} 
                                 between '#{export_params[:start_date]}' and '#{export_params[:end_date]}'
                                )
                              )

      sql_conditions[0].concat(%(and helpdesk_tickets.status in (#{RESOLVED}, #{CLOSED}))
                              ) if export_params[:ticket_state_filter].eql?("resolved_at")
      sql_conditions[0].concat(%(and helpdesk_tickets.status in (#{CLOSED}))
                              ) if export_params[:ticket_state_filter].eql?("closed_at")

      all_joins = index_filter.get_joins(sql_conditions)
      all_joins[0].concat(%( INNER JOIN helpdesk_ticket_states ON 
                     helpdesk_ticket_states.ticket_id = helpdesk_tickets.id AND 
                     helpdesk_tickets.account_id = helpdesk_ticket_states.account_id))
      csv_hash = export_params[:export_fields]
      headers = csv_hash.keys.sort
      select = "helpdesk_tickets.* "
      select = "DISTINCT(helpdesk_tickets.id) as 'unique_id' , #{select}" if sql_conditions[0].include?("helpdesk_tags.name")
      csv_string = FasterCSV.generate do |csv|
        csv << headers
        Account.current.tickets.find_in_batches(:select => select,
                                        :conditions => sql_conditions, 
                                        :include => [:ticket_states, :ticket_status, :flexifield,
                                                     :responder, :requester],
                                        :joins => all_joins
                                       ) do |items|
          items.each do |record|
            csv_data = []
            headers.each do |val|
              csv_data << record.send(csv_hash[val])
            end
            csv << csv_data
          end
        end
      end
      if (export_params[:later])
        Helpdesk::TicketNotifier.deliver_export(export_params, csv_string, User.current)
      else
        csv_string
      end
    end
  end
end