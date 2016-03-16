class Freshfone::Initiator::Outgoing
  include Freshfone::FreshfoneUtil
  include Freshfone::Endpoints
  include Freshfone::CallsRedisMethods

  attr_accessor :params, :current_account, :current_number, 
                :call_actions, :call_handler, :current_call
  
  def self.match?(params)
    params[:type] == "outgoing"
  end

  def initialize(params, current_account, current_number)
    self.params          = params
    self.current_account = current_account
    self.current_number  = current_number
    self.call_actions    = Freshfone::CallActions.new(params, current_account, current_number)
  end

  def process
    return reject_outgoing_call unless register_outgoing_device

    self.current_call = call_actions.register_outgoing_call
    telephony.initiate_agent_conference({ :wait_url => agent_wait_url(current_call.id) }) # SpreadsheetL 56
  end

  def telephony
    @telephony = Freshfone::Telephony.new(params, current_account, current_number, current_call)
  end

end