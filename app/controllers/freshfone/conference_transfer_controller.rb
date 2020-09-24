class Freshfone::ConferenceTransferController < FreshfoneBaseController
  include Freshfone::FreshfoneUtil
  include Freshfone::CallHistory
  include Freshfone::CallsRedisMethods
  include Freshfone::Endpoints
  include Freshfone::Conference::EndCallActions
  include Freshfone::Conference::TransferMethods
  include Freshfone::NumberValidator

  before_filter :validate_trial, :only => [:initiate_transfer], :if => :trial?
  before_filter :validate_transfer_request, only: [:initiate_transfer]
  before_filter :set_group_transfer_param, :only => [:initiate_transfer]
  before_filter :initialize_transfer, :only => [:initiate_transfer]
  before_filter :update_conference_sid, :only => [:transfer_agent_wait]
  before_filter :select_current_call, :only => [:initiate_transfer]
  before_filter :select_child_call, :only => [:resume_transfer, :cancel_transfer]
  before_filter :cancel_child_call, :only => [:transfer_success], if: :call_in_progress? #checking for parent call is in progress, if so then child is canceled.
  before_filter :transfer_answered, :only => [:transfer_success], unless: :intended_agent_for_transfer?
  after_filter :remove_conf_transfer_job, :only => [:transfer_success]
  before_filter :check_current_call, :only => [:cancel_transfer, :resume_transfer]
  before_filter :validate_external_number, only: :initiate_transfer, if: :external_number?
  
  def initiate_transfer
    initiate_conference_transfer
    trigger_conference_transfer_wait(current_call)
    render :json => {:status => :transferred}
  end

  def transfer_agent_wait
    telephony(current_call.parent).initiate_transfer_on_unhold
    render :xml => telephony.play_unhold_message  
  end

  def transfer_success
    render xml: handle_transfer_success
  end

  def complete_transfer
    notifier.notify_transfer_success(current_call)
    current_call.disconnect_source_agent
    telephony.initiate_transfer_on_unhold
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
    telephony(parent_call).initiate_transfer_fall_back
    render :json => {:status => :unhold_initiated}
  end
 
  def resume_transfer
    parent_call = current_call.parent
    render :json => {:status => :error} and return unless (parent_call.present? && parent_call.onhold?)
    telephony(parent_call).initiate_transfer_fall_back
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

    def select_child_call
      child_call = current_call.children.last
      @current_call = child_call if child_call.present?
    end

    def set_group_transfer_param
      params[:group_transfer] = "true" if (!params[:group_id].blank? && params[:group_id] != 0)
    end

    def check_current_call
      render :json => {:status => :error} and return if current_call.blank?
    end

    def get_agent_id
      split_client_id(params[:To])      
    end

    def validate_trial
      render json: { status: :error } if external_number?
    end

    def validate_transfer_request
      render json: { status: :error } and
        return if params[:CallSid].blank? || current_call.blank?
    end

    def external_number?
      params[:external_number].present?
    end

    def validate_external_number
      render json: { status: :error } if fetch_country_code("+#{params[:target]}").blank?
    end
end