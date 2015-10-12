class Freshfone::ConferenceTransferController < FreshfoneBaseController
  include Freshfone::FreshfoneUtil
  include Freshfone::CallHistory
  include Freshfone::CallsRedisMethods
  include Freshfone::Endpoints
  include Freshfone::Conference::EndCallActions
  include Freshfone::Conference::TransferMethods

  before_filter :set_group_transfer_param, :only => [:initiate_transfer]
  before_filter :initialize_transfer, :only => [:initiate_transfer]
  before_filter :update_conference_sid, :only => [:transfer_agent_wait]
  before_filter :select_current_call, :only => [:initiate_transfer]
  before_filter :set_child_call_status, :only => [:transfer_success]
  before_filter :handle_simultaneous_answer, :only => [:transfer_success]
  after_filter :remove_conf_transfer_job, :only => [:transfer_success]
  before_filter :check_current_call, :only => [:cancel_transfer, :resume_transfer]
  
  def initiate_transfer
    initiate_conference_transfer
    trigger_conference_transfer_wait(current_call)
    render :json => {:status => :transferred}
  end

  def transfer_agent_wait
    telephony.initiate_transfer_on_unhold(current_call.parent)
    render :xml => telephony.play_unhold_message  
  end

  def transfer_success
    begin
      notifier.notify_transfer_success(current_call)
      notifier.cancel_other_agents transfer_leg
      current_call.completed!
      render :xml => telephony.initiate_agent_conference({
                      :wait_url => target_agent_wait_url, 
                      :sid => params[:CallSid] })
    rescue Exception => e
      Rails.logger.error "Error in conference transfer success for #{current_account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      current_call.cleanup_and_disconnect_call
      empty_twiml
    end
  end

  def complete_transfer
    notifier.notify_transfer_success(current_call)
    current_call.disconnect_source_agent
    telephony.initiate_transfer_on_unhold(current_call)
    current_call.completed!
    render :json => {:status => :success}
  end

  def transfer_source_redirect
    child_sid = current_call.children.last.call_sid
    render :xml => telephony.initiate_customer_conference({
      :sid => child_sid,
      :moderation_params => {:beep => true, :startConferenceOnEnter => true}
    })
  end

  def cancel_transfer
    parent_call = current_call.parent
    render :json => {:status => :error} and return unless (parent_call.present? && parent_call.onhold? && current_call.ringing?)
    current_call.canceled!
    parent_call.inprogress!
    notifier.cancel_other_agents(current_call)
    telephony.initiate_transfer_fall_back(parent_call)
    render :json => {:status => :unhold_initiated}
  end
 
  def resume_transfer
    parent_call = current_call.parent
    render :json => {:status => :error} and return unless (parent_call.present? && parent_call.onhold?)
    telephony.initiate_transfer_fall_back(parent_call)
    parent_call.inprogress!
    render :json => {:status => :unhold_initiated}
  end


  def disconnect_agent
    begin
      current_call.parent.disconnect_source_agent
      render :json => {:status => :success}
    rescue Exception => e
      Rails.logger.error "Error in conference source agent disconnect #{current_account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      render :json => {:status => :error }
    end
  end

  private

    def initialize_transfer
      @target_agent_id = group_transfer? ? params[:group_id] : params[:target] #if group transfer agent_id is group_id
      @source_agent_id = current_user.id
      clear_client_calls
    end

    def transfer_leg
      agent_id = split_client_id(params[:To])
      transfer_leg = fetch_and_update_child_call(params[:call], params[:CallSid], agent_id)
    end

    def clear_client_calls
      key = FRESHFONE_CLIENT_CALL % { :account_id => current_account.id }
      remove_from_set(key, current_call.call_sid)
    end


    def notifier
      current_number = current_call.freshfone_number
      @notifier ||= Freshfone::Notifier.new(params, current_account, current_user, current_number)
    end

    def validate_twilio_request
      @callback_params = params.except(*[:call, :hold_queue, :type])
      super
    end

    def select_current_call
      @current_call = current_call.parent unless (current_call.inprogress? || current_call.onhold?)
      #Scenario: if an agent use cancel/resume functionality first then he try to make another transfer
    end

    def set_group_transfer_param
      params[:group_transfer] = "true" if (!params[:group_id].blank? && params[:group_id] != 0)
    end

    def check_current_call
      render :json => {:status => :error} and return if current_call.blank?
    end

    def set_child_call_status
      return unless current_call.inprogress? #checking for parent call is in progress, if so then child is canceled.
      current_call.children.last.canceled!
      empty_twiml and return
    end

    def handle_simultaneous_answer
        incoming_answered and return unless intended_agent?
    end

    def incoming_answered
      @transfer_leg_call.meta.update_pinged_agents_with_response(get_agent_id, "canceled") if @transfer_leg_call.meta.present?
      render :xml => telephony.incoming_answered(@transfer_leg_call.agent) 
    end

    def intended_agent?
      @transfer_leg_call = current_call.children.last
      return true if @transfer_leg_call.user_id.blank?
      @transfer_leg_call.user_id.to_s == get_agent_id
    end

    def get_agent_id
      split_client_id(params[:To])      
    end
end