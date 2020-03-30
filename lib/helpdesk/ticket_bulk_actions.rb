class Helpdesk::TicketBulkActions
  include Helpdesk::ToggleEmailNotification
  include Helpdesk::TagMethods

  class InvalidActionError < StandardError
  end

  def initialize(params)
    params.symbolize_keys!
    @action = params[:id] || params[:action]
    @change_hash = construct_ticket_change(params)
    @tags = params[:tags] unless params[:tags].nil?
    raise InvalidActionError unless ( @change_hash.present? or @tags )
  end

  def perform(ticket)
    @change_hash.each do |key, value|
      value = nil if value == '-1'
      ticket.safe_send("#{key}=", value) if (value.nil? || value.present? || value.is_a?(FalseClass)) and ticket.respond_to?("#{key}=")
    end
    update_tags(@tags,false,ticket) if @tags
    if [:spam, :deleted].include? @action
      store_dirty_tags(ticket)
    elsif [:unspam, :restore].include? @action
      restore_dirty_tags(ticket)
    end
    ticket.save
  end

  private
    def construct_ticket_change(params)
      action = params[:id] || params[:action]
      params[:helpdesk_ticket][:bulk_updation] = true unless  params[:helpdesk_ticket].nil?
      user_id = User.current.present? ? User.current.id : nil;
      change_hash= {
        :close_multiple  => { :status => Helpdesk::Ticketfields::TicketStatus::CLOSED },
        :pick_tickets    => { :responder_id => user_id },
        :assign          => { :responder_id => params[:responder_id] ? 
                                params[:responder_id] 
                                : user_id },
        :update_multiple => params[:helpdesk_ticket],
        :spam            => { :spam => true },
        :delete          => { :deleted => true },
        :destroy          => { :deleted => true },
        :unspam          => { :spam => false },
        :restore          => { :deleted => false }
      }
      # puts change_hash[action.to_sym]
      change_hash[action.to_sym]
    end
end
