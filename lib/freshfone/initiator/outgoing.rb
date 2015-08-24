class Freshfone::Initiator::Outgoing
  include Freshfone::FreshfoneUtil
  include Freshfone::Endpoints
  include Freshfone::CallsRedisMethods

  attr_accessor :params, :current_account, :current_number, 
                :call_actions, :call_handler, :telephony
  
  def self.match?(params)
    params[:type] == "outgoing"
  end

  def initialize(params, current_account, current_number)
    self.params          = params
    self.current_account = current_account
    self.current_number  = current_number
    self.call_actions    = Freshfone::CallActions.new(params, current_account, current_number)
    self.telephony       = Freshfone::Telephony.new(params, current_account, current_number)
  end

  def process
    return reject_outgoing_call unless register_outgoing_device

    current_call = call_actions.register_outgoing_call
    telephony.initiate_agent_conference({ :wait_url => agent_wait_url(current_call.id) }) # SpreadsheetL 56
  end

  private
    def register_outgoing_device
      agent_user_id = outbound_call_agent_id
      set_outgoing_device([agent_user_id]) unless agent_user_id.blank?
    end

    def reject_outgoing_call
      agent_user_id = outbound_call_agent_id
      unless agent_user_id.blank?
        agent = current_account.freshfone_users.find_by_user_id(agent_user_id).busy!
        Resque::enqueue(Freshfone::Jobs::BusyResolve, { :agent_id => agent_user_id })
      end
      telephony.reject
    end

    def outbound_call_agent_id
      split_client_id(params[:From]) || params[:agent]
    end

end