class Freshfone::QueueController < FreshfoneBaseController

  include Freshfone::FreshfoneUtil
  include Freshfone::NumberMethods
  include Freshfone::Queue
  include Freshfone::CallHistory
  include Redis::RedisKeys
  include Redis::IntegrationsRedis

  
  before_filter :load_hunt_options_for_conf, :only => [:enqueue]
  before_filter :add_caller_to_redis_queue, :only => [:enqueue]
  before_filter :cleanup_redis_on_queue_complete, 
              :only => [:hangup, :trigger_voicemail, :trigger_non_availability, :quit_queue_on_voicemail, :dequeue]
  before_filter :remove_wait_job,
              :only => [:hangup, :quit_queue_on_voicemail, :dequeue]
  after_filter :update_call, :only => :hangup
  
  def enqueue
    enqueue_caller
    trigger_queue_wait
  end

  def trigger_voicemail
    render :xml => call_initiator.initiate_voicemail
  end

  def trigger_non_availability
    call_initiator.queued = true #Makes sure welcome message is prevented
    if freshfone_conference?
      render :xml => telephony.return_non_availability(false)
    else
      render :xml => call_initiator.return_non_availability
    end
  end

  def bridge
    bridge_queued_call #if this is faster, replace with add_to_call_queue_worker.
    render :json => {:status => :success}
  end

  def dequeue
    render :xml => ( freshfone_conference? ? incoming_initiator.dequeue(params[:client])  : current_call_flow.dequeue(params[:client]) )
  end

  def hangup
    queued_calls = get_key redis_queue_key
    members = queued_calls.nil? ? [] : JSON.parse(queued_calls)
    remove_call_from_queue(members, params[:hunt_id]) unless members.empty?
    members.empty? ? remove_key(redis_queue_key) : 
                        set_key(redis_queue_key, members.to_json)
    render :nothing => true
    ensure
      unless BRIDGE_STATUS.include?(params[:QueueResult])
        Resque::enqueue_at(2.minutes.from_now, 
                           Freshfone::Jobs::CallBilling,
                           { :account_id => current_account.id, 
                             :call_sid => params[:CallSid]})
        Rails.logger.debug "Added FreshfoneCostJob for call sid(Quit Queue)::::: #{params[:CallSid]}}"
      end
  end

  def quit_queue_on_voicemail
    return empty_twiml unless params[:Digits] == '*'
    queued_member = current_account.freshfone_subaccount.queues.get(params[:QueueSid]).members.get(params[:CallSid])
    queued_member.dequeue("#{host}/freshfone/queue/trigger_voicemail")
    render :text => "Dequeued Call #{params[:CallSid]} from #{params[:QueueSid]}"
  end

  private
    def update_call
      current_call.update_call(params) unless BRIDGE_STATUS.include?(params[:QueueResult])
    end

    def trigger_queue_wait
      unless get_key(resque_queue_wait_key)
        set_key(resque_queue_wait_key, true)
        Resque.enqueue_at(queue_wait_time, Freshfone::QueueWait , 
          { :account_id => current_account.id,
            :call_sid => params[:CallSid],
            :queue_sid => params[:QueueSid] })
      end
    end

    def redis_queue_key
      return send("#{params[:hunt_type]}_queue_key") if priority_queue?
      default_queue_key
    end

    def remove_call_from_queue(members, performer)
      if priority_queue?
        members[performer].delete(params[:CallSid])
        members.delete(performer) unless members[performer].any?
      else
        members.delete(params[:CallSid])
      end
    end

    def priority_queue?
      @priority_queue ||= ["agent", "group"].include?(params[:hunt_type])
    end

    def remove_wait_job
      Resque.remove_delayed(Freshfone::QueueWait , 
        {:account_id => current_account.id, :call_sid => params[:CallSid], :queue_sid => params[:QueueSid]})
    end

    def cleanup_redis_on_queue_complete
      remove_key resque_queue_wait_key
    end

		def call_initiator
			@call_initiator ||= Freshfone::CallInitiator.new(params, current_account, current_number)
		end

		def current_call_flow
			@current_call_flow ||= Freshfone::CallFlow.new(params, current_account, current_number, current_user)
		end

    def incoming_initiator
      @incoming_initiator ||= Freshfone::Initiator::Incoming.new(params, current_account, current_number)
    end

    def validate_twilio_request
      @callback_params = params.except(*[:hunt_id, :hunt_type, :force_termination, :client])
      super
    end

    def freshfone_conference?
      current_account.features?(:freshfone_conference)
    end

    def telephony
      @telephony ||= Freshfone::Telephony.new(params, current_account, current_number)
    end
end

