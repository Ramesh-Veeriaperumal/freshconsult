class Helpdesk::TicketBulkActions
  include Helpdesk::ToggleEmailNotification

  class InvalidActionError < StandardError
  end

  def initialize(params)
    params.symbolize_keys!
    @change_hash = construct_ticket_change(params)
    raise InvalidActionError unless @change_hash.present?
  end

  def perform(ticket)
    update_ticket(ticket)
  end

  private
    def construct_ticket_change(params)
      action = params[:id] || params[:action]
      user_id = User.current.present? ? User.current.id : nil;
      change_hash= {
        :close_multiple  => { :status => Helpdesk::Ticketfields::TicketStatus::CLOSED },
        :pick_tickets    => { :responder_id => user_id },
        :assign          => { :responder_id => params[:responder_id] ? 
                                params[:responder_id] 
                                : user_id },
        :update_multiple =>  params[:helpdesk_ticket], 
        :spam            => { :spam => true },
        :delete          => { :deleted => true }
      }
      change_hash[action.to_sym]
    end

    def update_ticket(ticket)
      @change_hash.each do |key, value|
        ticket.send("#{key}=", value) if ticket.respond_to?("#{key}=")
      end
      ticket.save
    end
end
