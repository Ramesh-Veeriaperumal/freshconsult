class Freshfone::Initiator::AgentCallLeg
  include Freshfone::FreshfoneUtil
  include Freshfone::Presence
  include Freshfone::Queue
  include Freshfone::Endpoints
  include Freshfone::Disconnect
  include Freshfone::Conference::Branches::RoundRobinHandler
  include Freshfone::SimultaneousCallHandler
  include Redis::OthersRedis
  include Freshfone::CallsRedisMethods

  attr_accessor :params, :current_account, :current_number, :current_call, :current_user,
                :available_agents, :busy_agents, :freshfone_users, :routing_type

  def initialize(params, current_account, current_number, call_actions, telephony)
    self.params          = params
    self.current_account = current_account
    self.current_number  = current_number
    self.freshfone_users = current_account.freshfone_users
    @call_actions        = call_actions
    @telephony           = telephony
  end

  def process
    begin
      self.current_call ||= select_current_call
      return handle_simultaneous_answer if simultaneous_accept?
      return browser_agent_leg.process if browser_leg?
      return telephony.no_action unless current_call
      return resolve_simultaneous_calls if simultaneous_call? && disconnect_leg?
      return initiate_disconnect if disconnect_leg? || not_in_progress?
     
      if current_call.ringing? || current_call.queued?
        current_call.update_attributes(
          :call_status => Freshfone::Call::CALL_STATUS_HASH[:connecting], 
          :user_id => params[:agent_id])
        process_agent_leg
      else
        handle_simultaneous_answer
      end
    rescue Exception => e
      Rails.logger.error "Error in processing incoming for #{current_account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      current_call.cleanup_and_disconnect_call
      telephony.no_action
    end
  end

  def process_agent_leg
    begin
      if current_call.connecting? && agent_connected?
        process_call_accept_callbacks
        notifier.cancel_other_agents(current_call)
      
        telephony.current_number = current_call.freshfone_number
        telephony.initiate_agent_conference({
          :wait_url => "", 
          :sid => current_call.call_sid })
      else
        handle_simultaneous_answer
      end
    rescue Exception => e
      Rails.logger.error "Error in conference incoming agent wait for #{current_account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      current_call.cleanup_and_disconnect_call
      telephony.no_action
    end
  end
  
  private
    def simultaneous_accept?
      return if params[:CallStatus] != "in-progress"
      simultaneous_accept = !add_member_to_redis_set(simultaneous_accept_key, current_call.id)
      set_others_redis_expiry(simultaneous_accept_key, 20) unless simultaneous_accept
      simultaneous_accept
    end

    def simultaneous_accept_key
       @simultaneous_accept_key ||= FRESHFONE_SIMULTANEOUS_ACCEPT % {:account_id => current_account.id, :call_id => current_call.id }
    end		
  
    def select_current_call
      call = select_call
      child_call = call.children.ongoing_or_completed_calls.last
      return call if child_call.blank?
      child_call.meta.warm_transfer_meta? ? child_call : call
    end

    def select_call
      return current_account.freshfone_calls.find(call_id) if call_id.present?
      current_account.freshfone_calls.find_by_dial_call_sid(params[:CallSid]) if params[:CallSid].present?
    end

    def call_id
      params[:caller_sid] || params[:call_id] || params[:call]
    end
    
    def handle_simultaneous_answer
      Rails.logger.info "Handle Simultaneous Answer For Account Id :: #{current_account.id}, Call Id :: #{current_call.id}, CallSid :: #{params[:CallSid]}, AgentId :: #{params[:agent_id]}"
      return incoming_answered unless intended_agent?
      current_call.noanswer? ? telephony.incoming_missed : incoming_answered
    end

    def process_call_accept_callbacks
      @call_actions.update_agent_leg(current_call)
      params[:agent] = params[:agent] || params[:agent_id]
      update_presence_and_publish_call(params) if params[:agent].present?
      @call_actions.update_agent_leg_response(params[:agent_id],'accepted',current_call)
      update_call_meta_for_forward_calls if params[:forward].present?
    end

    def not_in_progress?
      Freshfone::Call::INTERMEDIATE_CALL_STATUS.exclude?(current_call.call_status) # SpreadsheetL 21
    end

    def disconnect_leg?
      params[:leg_type] == "disconnect"
    end

    def connect_leg?
      params[:leg_type] == "connect"
    end

    def browser_leg?
      params[:forward].blank? && params[:external_number].blank? &&
        params[:external_transfer].blank? && params[:forward_call].blank? # checking forward cases alone
    end

    def browser_agent_leg
      @browser_agent_leg ||= Freshfone::Initiator::BrowserAgentLeg.new(params, current_account, current_number)
    end	
end