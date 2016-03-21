class Freshfone::Initiator::AgentCallLeg
  include Freshfone::FreshfoneUtil
  include Freshfone::Presence
  include Freshfone::Queue
  include Freshfone::Endpoints
  include Freshfone::AgentsLoader
  include Freshfone::Disconnect
  include Freshfone::Conference::Branches::RoundRobinHandler

  attr_accessor :params, :current_account, :current_number, :current_call, :current_user,
                :notifier, :available_agents, :busy_agents, :freshfone_users, :routing_type

  

  def initialize(params, current_account, current_number, call_actions, telephony)
    self.params          = params
    self.current_account = current_account
    self.current_number  = current_number
    self.freshfone_users = current_account.freshfone_users
    @call_actions        = call_actions
    @telephony           = telephony
    self.notifier        = Freshfone::Notifier.new(params, current_account)
  end

  def process
    begin
      self.current_call ||= current_account.freshfone_calls.find(params[:caller_sid] || params[:call])
      return telephony.no_action unless current_call
      return process_agent_leg if connect_leg?
      return resolve_simultaneous_calls if simultaneous_call?
      return initiate_disconnect if disconnect_leg? || not_in_progress?
      
      if current_call.ringing? || current_call.queued?
        current_call.update_attributes(
          :call_status => Freshfone::Call::CALL_STATUS_HASH[:connecting], 
          :user_id => params[:agent_id])
        initiate_agent_leg
      else
        handle_simultaneous_answer
      end
    rescue Exception => e
      Rails.logger.error "Error in processing incoming for #{current_account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      current_call.cleanup_and_disconnect_call
      telephony.no_action
    end
  end

  def initiate_agent_leg
    telephony.redirect_call_to_conference(params[:CallSid], "#{connect_agent_url}#{forward_params}")
    telephony.no_action
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
    def handle_simultaneous_answer
      Rails.logger.info "Handle Simultaneous Answer For Account Id :: #{current_account.id}, Call Id :: #{current_call.id}, CallSid :: #{params[:CallSid]}, AgentId :: #{params[:agent_id]}"
      return incoming_answered unless intended_agent?
      current_call.noanswer? ? telephony.incoming_missed : incoming_answered
    end

    def incoming_answered
      telephony.incoming_answered(current_call.agent)
    end

    def process_call_accept_callbacks
      @call_actions.update_agent_leg(current_call)
      params[:agent] = params[:agent] || params[:agent_id]
      update_presence_and_publish_call(params) if params[:agent].present?
      @call_actions.update_agent_leg_response(params[:agent_id],'accepted',current_call)
      update_call_meta_for_forward_calls if params[:forward].present?
    end

    def intended_agent?
      return true if current_call.user_id.blank?
      current_call.user_id.to_s == params[:agent_id]
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

    def resolve_simultaneous_calls
      log_simultaneous_call
      telephony.redirect_call(current_call.call_sid, simultaneous_call_queue_url)
      telephony.no_action
    end

    def simultaneous_call?
      disconnect_leg? && (all_agents_busy? || invalid_call? )
    end

    def all_agents_busy?
      self.current_number =  self.current_call.freshfone_number
      check_available_and_busy_agents
      available_agents.empty? and busy_agents.any? and params[:CallStatus]=="busy" and !transfer_call?
    end

    def log_simultaneous_call
      Rails.logger.debug "Call redirected to queue : Account : #{current_account.id} : agent : 
                          #{params[:agent_id]} : call : #{current_call.call_sid}"
      Rails.logger.debug "Redirected call #{current_call.call_sid} :: #{busy_agents.map(&:id)}"
    end

    def invalid_call? 
    # Edge case: To prevent incoming call for an agent with a call (bug #15531)
      return if (available_agents.length != 1)
      user_id = available_agents.first.user_id
      current_account.freshfone_calls.agent_progress_calls(user_id).present?
    end

    def telephony
      @telephony ||= Freshfone::Telephony.new(params, current_account, current_number, current_call)
      @telephony.current_call ||= current_call
      @telephony
    end

end