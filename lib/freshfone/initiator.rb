class Freshfone::Initiator
  include Freshfone::CallValidator
  include Freshfone::FreshfoneUtil

  CALL_TYPES = [ 
                  Freshfone::Initiator::Incoming, 
                  Freshfone::Initiator::Outgoing,
                  Freshfone::Initiator::Transfer,
                  Freshfone::Initiator::Record,
                  Freshfone::Initiator::Sip
               ]

  attr_accessor :params, :call_resolver, :current_account

  def initialize(params={}, current_account=nil, current_number=nil, current_user=nil, current_call=nil)
    self.params          = params
    self.current_account = current_account
    @current_number      = current_number
    @current_user        = current_user
    @current_call        = current_call

    params[:type] ||= resolve_call_type

  end

  def resolve_call
    return telephony.reject unless preconditions?
    call_resolver = CALL_TYPES.detect { |type| type.match?(params) }.new(params, current_account, @current_number)
    return call_resolver.process
  end

  def resolve_ivr
    incoming_handler = Freshfone::Initiator::Incoming.new(params, current_account, @current_number)
    incoming_handler.process_ivr
  end

  private
    def telephony
      @telephony ||= Freshfone::Telephony.new(params, current_account, @current_number)
    end

    def outgoing?
      params[:PhoneNumber].present? && params[:From].present? && has_client_id?
    end

    def has_client_id?
      params[:From].match(/(client:)/) ? true : false
    end

    def resolve_call_type
      return sip_type if sip_call?
      outgoing? ? "outgoing" : "incoming"
    end

    def sip_type
      params[:PhoneNumber] = sip_number  
      return "sip"
    end
end