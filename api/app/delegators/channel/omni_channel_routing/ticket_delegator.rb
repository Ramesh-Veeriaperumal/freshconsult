class Channel::OmniChannelRouting::TicketDelegator < BaseDelegator
	
  validate :responder_presence, if: :responder_id
  
  def responder_presence
    responder = Sharding.run_on_slave do
      account.technicians.where(id: responder_id, helpdesk_agent: true).first
    end
    if responder.nil?
      errors[:responder] << :"can't be blank"
    else
      self.responder = responder
    end
  end
end
