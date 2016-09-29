class Freshfone::Initiator::BrowserAgentLeg
  include Freshfone::Disconnect
  include Freshfone::Endpoints
  include Freshfone::FreshfoneUtil
  include Freshfone::Queue
  include Freshfone::Conference::Branches::RoundRobinHandler
  include Freshfone::Conference::TransferMethods
  include Freshfone::CallHistory


  attr_accessor :params, :current_account, :current_number

  def initialize(params, current_account, current_number=nil)
    self.params           = params
    self.current_account  = current_account
    self.current_number   = current_number
    @call_actions = call_actions
  end

  def process
    agent_leg_type  = params[:agent_leg_type]
    case agent_leg_type
    when 'agent_leg'
      agent_leg
    when 'agent_transfer_leg'
      agent_transfer_leg
    when 'agent_warm_transfer_leg'
      agent_warm_transfer_leg
    end
  end

  private

    def agent_leg
      return telephony.no_action if current_call.blank?
      return handle_simultaneous_answer unless current_call.ringing?
      process_call_accept_callbacks
      telephony.initiate_agent_conference({
        :wait_url => "", 
        :sid => current_call.call_sid })
    end

    def agent_transfer_leg
      @current_call = current_call.parent if current_call.transferred_leg?
      params[:call] = current_call.id # setting the parent call itself
      return cancel_child_call if call_in_progress? #checking for parent call is in progress, if so then child is canceled.
      return transfer_answered unless intended_agent_for_transfer?
      remove_conf_transfer_job
      handle_transfer_success
    end

    def agent_warm_transfer_leg
      warm_transfer_leg.update_inprogress_status(params[:CallSid])
      handle_warm_transfer_success
    end

    def process_call_accept_callbacks
      call_actions.update_agent_leg(current_call)
      call_actions.cancel_browser_agents(current_call)
      notifier.cancel_mobile_agents(current_call)
    end

    def call_actions
      @call_actions ||= Freshfone::CallActions.new(params, current_account)
    end

    def notifier(call = current_call)
      current_number = call.freshfone_number
      @notifier ||= Freshfone::Notifier.new(params, current_account, current_user, current_number)
    end

    def current_user
      current_account.users.find(agent_id)
    end

    def agent_id
      split_client_id(params[:From])
    end
end
