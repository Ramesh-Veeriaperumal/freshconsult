class Freshfone::Initiator::Sip
  include Freshfone::FreshfoneUtil
  include Freshfone::Endpoints
  include Freshfone::CallsRedisMethods
  
  attr_accessor :params, :current_account, :current_number, 
                :call_actions, :call_handler
  

  def self.match?(params)
    params[:type] == "sip"
  end
  
  def initialize(params, current_account, current_number)
    self.params          = params
    self.current_account = current_account
    self.current_number  = current_number
    self.call_actions    = Freshfone::CallActions.new(params, current_account, current_number)
  end

  def process
    return reject_outgoing_call unless register_outgoing_device
    
    current_call = call_actions.register_outgoing_call
    current_call.create_sip_meta
    update_user_presence
    telephony.initiate_agent_conference({ :wait_url => agent_wait_url(current_call.id) })
  end

private
    def update_user_presence
      current_account.freshfone_users.find_by_user_id(sip_user_id).busy! if sip_user_id.present?
    end

    def telephony
      @telephony ||= Freshfone::Telephony.new(params, current_account, current_number, current_call)
    end
end
