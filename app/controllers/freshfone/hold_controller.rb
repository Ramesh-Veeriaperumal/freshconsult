class Freshfone::HoldController < FreshfoneBaseController
  include Freshfone::FreshfoneUtil
  include Freshfone::CallHistory
  include Freshfone::NumberMethods
  include Freshfone::AgentsLoader

  before_filter :valid_hold_request?, :only => [:add, :remove]
  before_filter :reset_resume_call, :only =>[:add, :wait, :remove, :unhold]
  before_filter :initialize_hold, :only => [:wait]
  before_filter :update_child_leg, :only => [:transfer_unhold]

  def add
    begin
      if valid_call?
        current_call.onhold!
        customer_sid = outgoing_transfer?(current_call) ? current_call.root.customer_sid : current_call.customer_sid
        
        telephony.initiate_hold(customer_sid, {call: current_call.id})
        render :json => {:status => :hold_initiated}
      else
        render :json => {:status => :error}
      end
    rescue Exception => e 
      Rails.logger.error "Error while adding the Customer to hold for #{params[:CallSid]} :: #{current_account.id} \n #{e.message} \n #{e.backtrace.join("\n\t")}"
      render :json => error_handler(:json) # Spreadheet L 67, 69
    end  
  end

  def initiate
    begin
      render :xml => telephony.hold_enqueue
    rescue Exception => e
      message = "Error while adding to hold queue for #{params[:CallSid]} :: #{current_account.id} \n #{e.message}"
      Rails.logger.error "#{message} \n #{e.backtrace.join("\n\t")}"
      render :xml => error_handler(:xml, "#{message} \n #{e.backtrace.first(2).join("\n\t")}") # Spreadheet L 67, 69
    end
  end

  def wait
    begin
      notifier.notify_call_hold(current_call)
      transfer_notifier(current_call, params[:target], params[:source]) if params[:transfer]
      render :xml => telephony.play_hold_message
    rescue Exception => e
      message = "Error in adding caller to wait for #{params[:CallSid]} :: #{current_account.id} \n #{e.message}"
      Rails.logger.error "#{message} \n #{e.backtrace.join("\n\t")}"
      render :xml => error_handler(:xml, "#{message} \n #{e.backtrace.first(2).join("\n\t")}") # Spreadheet L 67, 68, 69
    end
  end

  def remove
    begin
      if current_call.onhold?
        telephony.initiate_unhold(current_call)
        render :json => {:status => :unhold_initiated}
      else
        render :json => {:status => :error}
      end
    rescue Exception => e
      Rails.logger.error "Error in Removing from Hold | CallSid: #{params[:CallSid]} :: #{current_account.id} \n #{e.message}\n #{e.backtrace.join("\n\t")}"  
      render :json => error_handler(:json) # Spreadheet L 68
    end
  end

  def unhold
    begin
      telephony.unmute_participants(current_call)
      #Adding back to the original conference
      current_call.inprogress!
      notifier.notify_call_unhold(current_call)
      agent_sid = transfered_leg?(current_call) ? current_call.dial_call_sid : current_call.call_sid
      render :xml => telephony.initiate_customer_conference({
                      :sid => agent_sid,
                      :moderation_params => {:beep => true, :startConferenceOnEnter => true} })
    rescue Exception => e
      message = "Error in Unhold | Adding customer back to conference for #{params[:CallSid]} :: #{current_account.id} \n #{e.message}"
      Rails.logger.error "#{message} \n #{e.backtrace.join("\n\t")}"
      render :xml => error_handler(:xml, "#{message} \n #{e.backtrace.first(2).join("\n\t")}") # Spreadheet L 68
    end
  end

  def quit
    current_call.add_to_hold_duration(params['QueueTime'])
    render :xml => telephony.no_action
  end

  def transfer_unhold
    begin
      render :xml => telephony.initiate_customer_conference({
                      :sid => params[:child_sid],
                      :moderation_params => {:beep => true, :startConferenceOnEnter => true} })
    rescue Exception => e
      message = "Error in transfer Unhold | Adding customer back to conference for #{params[:CallSid]} :: #{current_account.id} \n #{e.message}"
      Rails.logger.error "#{message} \n #{e.backtrace.join("\n\t")}"
      render :xml => error_handler(:xml, "#{message} \n #{e.backtrace.first(2).join("\n\t")}") # Spreadheet L 68
    end
  end

  def transfer_fallback_unhold
    begin
      notifier.notify_transfer_reconnected(current_call)
      telephony.unmute_participants(current_call)
      render :xml => telephony.initiate_customer_conference({
                      :sid => conference_room_name_sid,
                      :moderation_params => {:beep => true, :startConferenceOnEnter => true} })
    rescue Exception => e
      message = "Error in transfer fallback Unhold"
      Rails.logger.error "#{message} \n #{e.backtrace.join("\n\t")}"
      current_call.disconnect_agent
      render :xml => error_handler(:xml, "#{message} \n #{e.backtrace.first(2).join("\n\t")}")
    end
  end

  private
    def initialize_hold
      params[:customer] = current_call.customer
      current_call.update_attributes(:hold_queue => params[:QueueSid])
      telephony.mute_participants(current_call)
    end

    def update_child_leg
      current_call.children.last.inprogress!
    end
    
    def telephony
      @telephony ||= Freshfone::Telephony.new(params, current_account, current_number)
    end

    def notifier
      @notifier ||= Freshfone::Notifier.new(params, current_account, current_user, current_number)
    end

    def validate_twilio_request
      @callback_params = params.except(*[:hold_queue, :call, :transfer, :source, :target, :child_sid, :transfer_type, :group_transfer, :external_transfer])
      super
    end


  def error_handler(format=nil, message="")
    current_call.disconnect_agent
    if format == :xml
      telephony.empty_twiml(message)
    elsif format == :json
      {:status => :error}
    end
  end

  def current_number # Spreadheet L 75
    current_call.freshfone_number
  end

  def conference_room_name_sid
    current_call.is_root? ? current_call.call_sid : current_call.dial_call_sid
  end

  def reset_resume_call#setting the parent call as current for resumed case for hold and wait.
    return if current_call.blank?
    #need to check if current call is child
    set_current_call(current_call.parent) if (current_call.busy? || current_call.noanswer? ||  current_call.canceled? || current_call.ringing?)
  end

  def valid_call?
    (current_call.inprogress? || current_call.canceled?)
  end

  def valid_hold_request?
    render :json => {:status => :error} and return unless (params[:CallSid].present? && current_call.present?)
  end
end