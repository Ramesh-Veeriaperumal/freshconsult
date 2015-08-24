class Freshfone::ConferenceController < FreshfoneBaseController
  include Freshfone::FreshfoneUtil
  include Freshfone::CallHistory
  include Freshfone::NumberMethods
  include Freshfone::Endpoints
  
  before_filter :update_conference_sid, :only => [:wait]
  before_filter :update_call_details, :only => [:incoming_agent_wait, :agent_wait]

  def wait
    begin
      notifier.notify_agents current_call
      render :xml => telephony.play_wait_music
    rescue Exception => e
      Rails.logger.error "Error in conference incoming caller wait for #{current_account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      current_call.cleanup_and_disconnect_call
      empty_twiml
    end
  end

  def incoming_agent_wait(caller_connected=false) #Used in round robin. Does not belong here
    begin
      telephony.redirect_call_to_conference(current_call.call_sid, connect_incoming_caller_url)
      caller_connected = true
      render :xml => telephony.play_agent_wait_music
    rescue Exception => e
      Rails.logger.error "Error in conference incoming agent wait for #{current_account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      current_call.cleanup_and_disconnect_call unless caller_connected
      empty_twiml
    end
  end

  def connect_incoming_caller
    begin
      current_call.inprogress!
      render :xml => telephony.initiate_customer_conference({
                      :wait_url => "", 
                      :moderation_params => {:beep => true, :startConferenceOnEnter => true} })

    rescue Exception => e
      Rails.logger.error "Error in conference incoming agent wait for #{current_account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      current_call.cleanup_and_disconnect_call
      empty_twiml
    end
  end

  def agent_wait #Outgoing call
    begin
      telephony.initiate_outgoing(current_call)
      render :xml => telephony.play_agent_wait_music
    rescue Exception => e
      Rails.logger.error "Error in conference incoming caller wait for #{current_account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      empty_twiml
    end
  end

  def outgoing_accepted
    call_actions.update_customer_leg(current_call)
    telephony.current_number = current_call.freshfone_number
    render :xml => telephony.initiate_customer_conference({
      :sid => current_call.call_sid,
      :moderation_params => {:beep => true, :startConferenceOnEnter => true}
    })
  end

  private
    def telephony
      current_number ||= current_call.freshfone_number
      @telephony ||= Freshfone::Telephony.new(params, current_account, current_number)
    end

    def notifier
      current_number = current_call.freshfone_number
      @notifier ||= Freshfone::Notifier.new(params, current_account, current_user, current_number)
    end

    def call_actions
      @call_actions ||= Freshfone::CallActions.new(params, current_account, current_number)
    end

    def validate_twilio_request
      @callback_params = params.except(*[:call, :room, :hold_queue, :type, :caller_id, :timeout])
      super
    end
    
end