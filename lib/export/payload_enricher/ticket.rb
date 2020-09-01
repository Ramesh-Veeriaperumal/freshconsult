class Export::PayloadEnricher::Ticket < Export::PayloadEnricher::Base 

  TICKET_PROPERTIES     = "ticket_properties"
  REQUESTER_ID          = "requester_id"
  COMPANY_ID            = "company_id"
  USER                  = "user"
  COMPANY               = "company"
  ACCOUNT_ID            = "account_id"
  DEFAULT_FIELDS        = %w(deleted spam responder_id group_id internal_agent_id internal_group_id).freeze
  LAG_TIME_DIFFERENCE   = 0.5.second

  def enrich
    if @sqs_msg[ACTION] != DESTROY
      @sqs_msg[TICKET_PROPERTIES].merge!(collect_properties(ticket_fields))
      @sqs_msg[TICKET_PROPERTIES][:user] = @sqs_msg[TICKET_PROPERTIES][REQUESTER_ID].nil? ? 
                {} : properties(user.properties, USER)
      @sqs_msg[TICKET_PROPERTIES][:company] = @sqs_msg[TICKET_PROPERTIES][COMPANY_ID].nil? ? 
                {} : properties(company.properties, COMPANY)
    end
    @sqs_msg
  end

  def queue_name
    :scheduled_ticket_export_queue
  end

  def latest_ticket_change?
    action_epoch = @sqs_msg["action_epoch"]
    return true if Time.now.utc >= Time.at(action_epoch).utc + LAG_TIME_DIFFERENCE
    fetch_object
    return false unless @ticket # New ticket scenario
    [@ticket, @ticket.ticket_states].compact.all? do |obj|
      obj.updated_at.utc >= Time.at(action_epoch).utc - LAG_TIME_DIFFERENCE
    end
  end

  private
  
  def ticket_fields
    @enricher_config.ticket_fields | DEFAULT_FIELDS
  end

  def fetch_object
    @ticket ||= Account.current.tickets.find_by_id(@sqs_msg[TICKET_PROPERTIES][ID])
  end

  def company
    Export::PayloadEnricher::Company.new(nil, @enricher_config, 
                                        @sqs_msg[TICKET_PROPERTIES][COMPANY_ID])
  end

  def user
    Export::PayloadEnricher::User.new(nil, @enricher_config, 
                                      @sqs_msg[TICKET_PROPERTIES][REQUESTER_ID])
  end

  def properties(data_hash, object)
    {
      :account_id => @sqs_msg[ACCOUNT_ID],
      :object => object,
      "#{object}_properties" => data_hash
    }
  end

end
