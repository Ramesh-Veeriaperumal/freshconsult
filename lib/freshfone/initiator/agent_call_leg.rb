class Freshfone::Initiator::AgentCallLeg
  include Freshfone::FreshfoneUtil
  include Freshfone::Presence
  include Freshfone::Queue
  include Freshfone::Endpoints
  include Freshfone::Conference::Branches::RoundRobinHandler

  attr_accessor :params, :current_account, :current_number, :current_call, :current_user,
                :notifier

  def initialize(params, current_account, current_number, call_actions, telephony)
    self.params          = params
    self.current_account = current_account
    self.current_number  = current_number
    @call_actions        = call_actions
    @telephony           = telephony
    self.notifier        = Freshfone::Notifier.new(params, current_account)
  end

  def process
    begin
      self.current_call ||= current_account.freshfone_calls.find(params[:caller_sid])
      return @telephony.no_action unless current_call
      return process_agent_leg if connect_leg?
      return disconnect if disconnect_leg? || not_in_progress?

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
      @telephony.no_action
    end
  end

  def initiate_agent_leg
    @telephony.redirect_call_to_conference(params[:CallSid], "#{connect_agent_url}#{forward_params}")
    @telephony.no_action
  end

  def process_agent_leg
    begin
      if current_call.connecting? && agent_connected?
        process_call_accept_callbacks
        notifier.cancel_other_agents(current_call)
      
        @telephony.current_number = current_call.freshfone_number
        @telephony.initiate_agent_conference({
          :wait_url => "", 
          :sid => current_call.call_sid })
      else
        handle_simultaneous_answer
      end
    rescue Exception => e
      Rails.logger.error "Error in conference incoming agent wait for #{current_account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      current_call.cleanup_and_disconnect_call
      @telephony.no_action
    end
  end

  def disconnect
    current_call ||= current_account.freshfone_calls.find(params[:caller_sid] || params[:call]) # Needs refactoring
    params[:CallStatus] = 'no-answer' if params[:AnsweredBy] == 'machine'
    remove_value_from_set(pinged_agents_key(current_call.id), params[:CallSid])
    @call_actions.update_agent_leg_response(params[:agent_id] || params[:agent], params[:CallStatus], current_call)
    @call_actions.update_external_transfer_leg_response(params[:external_number], params[:CallStatus], current_call) if params[:external_transfer].present? && params[:external_number].present?
    update_agent_last_call_at
    reset_outgoing_count
    transfer_reconnect_or_voicemail if current_call.meta.all_agents_missed? 
    handle_round_robin_calls if round_robin_call?
    update_call_duration_and_total_duration if (agent_connected? || external_transfer?) && params[:CallSid].present?
    current_call.disconnect_customer if (current_call.onhold? && agent_connected? && !child_ringing?(current_call))#fix for: agent disconnect not ending the customer on hold.
    @telephony.no_action
  end

  private
    def handle_simultaneous_answer
      Rails.logger.info "Handle Simultaneous Answer For Account Id :: #{current_account.id}, Call Id :: #{current_call.id}, CallSid :: #{params[:CallSid]}, AgentId :: #{params[:agent_id]}"
      return incoming_answered unless intended_agent?
      current_call.noanswer? ? @telephony.incoming_missed : incoming_answered
    end

    def agent_connected?
      current_call.user_id.present? && current_call.user_id.to_s == params[:agent_id]
    end

    def initiate_voicemail
      current_call ||= current_account.freshfone_calls.find(params[:caller_sid] || params[:call]) # Needs refactoring
      freshfone_number = current_call.freshfone_number
      @telephony.redirect_call(current_call.call_sid, redirect_caller_to_voicemail(freshfone_number.id))
    end

    def incoming_answered
      @telephony.incoming_answered(current_call.agent)
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

    def transfer_call?
      params[:transfer_call].present? || params[:external_transfer].present?
    end

    def not_in_progress?
      Freshfone::Call::INTERMEDIATE_CALL_STATUS.exclude?(current_call.call_status) # SpreadsheetL 21
    end

    def notify_source_agent_to_reconnect
      notifier.notify_source_agent_to_reconnect(current_call) unless canceled_call?
    end

    def transfer_reconnect_or_voicemail
      if transfer_call?
        call_params = params.merge({:DialCallSid => params[:CallSid], :DialCallStatus => params[:CallStatus]})
        call_params.merge!({ :direct_dial_number => format_external_number }) if params[:external_number].present? && params[:external_transfer].present?
        current_call.update_call(call_params)
        notify_source_agent_to_reconnect
      else
        check_for_queued_calls
        initiate_voicemail unless current_call.noanswer? #means client ended the call.
      end
    end

    def round_robin_call?
      params[:round_robin_call].present? && !current_call.meta.all_agents_missed? 
    end

    def update_call_duration_and_total_duration
        call = params[:external_transfer] == 'true' ?
          current_account.freshfone_calls.find_by_dial_call_sid(params[:CallSid]) : current_call
      return unless call.present? && params[:CallDuration].present?
      call.set_call_duration(params)
      call.save!
    end

    def disconnect_leg?
      params[:leg_type] == "disconnect"
    end

    def connect_leg?
      params[:leg_type] == "connect"
    end
  
  def reset_outgoing_count
    remove_device_from_outgoing(split_client_id(params[:From])) if current_call.outgoing?
  end

  def child_ringing?(call)
    child_call = call.children.last
    return if child_call.blank?
    child_call.ringing?
  end

  def canceled_call?
    params[:CallStatus] == "canceled"
  end

end