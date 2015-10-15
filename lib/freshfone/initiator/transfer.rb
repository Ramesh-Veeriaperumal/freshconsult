class Freshfone::Initiator::Transfer
  include Freshfone::FreshfoneUtil
  include Freshfone::Presence
  include Freshfone::AgentsLoader
  include Freshfone::Endpoints
  
  def self.match?(params)
    params[:type] == "transfer"
  end

  attr_accessor :params, :current_account, :current_number, :current_call

  def initialize(params, current_account, current_number)
    self.params          = params
    self.current_account = current_account
    self.current_number  = current_number || fetch_current_number#check this ? JOHN
    @call_actions        = Freshfone::CallActions.new(params, current_account, current_number)
    @telephony           = Freshfone::Telephony.new(params, current_account, current_number)
  end

  def process
    transfer_leg = fetch_and_update_child_call(params[:call],params[:CallSid])
    current_number = transfer_leg.freshfone_number
    connect_transfer(transfer_leg)
  end

  def process_mobile_transfer
    transfer_leg = fetch_and_update_child_call(params[:call],params[:CallSid], params[:agent_id])
    parent_call = current_account.freshfone_calls.find(params[:call])
    trigger_conference_transfer_wait(parent_call) if parent_call.present? && parent_call.onhold?
    connect_transfer(transfer_leg,{:wait_url => transfer_wait_url })
  end

  def connect_transfer(transfer_leg, options = {})
    parent_call = current_account.freshfone_calls.find(params[:call])
    if parent_call.onhold?
      transfer_leg.inprogress!
      if params[:transferType].blank?
        update_freshfone_presence(parent_call.agent, Freshfone::User::PRESENCE[:online])
        notifier.cancel_other_agents(transfer_leg)
        @telephony.initiate_transfer_on_unhold(parent_call) if parent_call.onhold?
        parent_call.completed!
      else #Warm Transfer
        @telephony.redirect_call_to_conference(parent_call.agent_sid, warm_transfer_url)
      end

      @telephony.current_number = parent_call.freshfone_number
      @telephony.initiate_agent_conference(options)
    else
      Rails.logger.debug "Call is not on hold:::::::: render empty twiml with a message"
      @telephony.empty_twiml("Call is not on hold. :method: #{params[:action]} : controller: #{params[:controller]}")
    end
  end

  private

  def fetch_current_number
    parent_call = current_account.freshfone_calls.find(params[:call])
    self.current_number = parent_call.number
  end

  def notifier
    @notifier ||= Freshfone::Notifier.new(params, current_account, nil, current_number)
  end

end