class Freshfone::CallObserver < ActiveRecord::Observer
	observe Freshfone::Call

  include Freshfone::NodeEvents
  include Freshfone::CallsRedisMethods
  include Freshfone::SubscriptionsUtil
  include Freshfone::AcwUtil
  
	def before_create(call)
		initialize_data_from_params(call)
		build_outgoing_browser_meta call if outgoing_meta_buildable? call
	end

  def after_create(freshfone_call)
    create_call_metrics(freshfone_call) if freshfone_call.account.features? :freshfone_call_metrics
    publish_new_warm_transfer(freshfone_call) if freshfone_call.account.features? :freshfone_warm_transfer
  end

	def before_save(freshfone_call)
		set_customer_on_ticket_creation(freshfone_call) if freshfone_call.customer_id.blank?
    update_caller_data(freshfone_call) if freshfone_call.caller.blank?
	end

  def after_update(call)
    account = call.account
    call.update_metrics if account.features? :freshfone_call_metrics
    trigger_disconnect_job(call) if disconnected?(call)
    if call.call_status_changed?
      publish_new_call_status(call)

      initiate_tracker(call) unless trial?
      update_pinged_agent_status(call) if ongoing_child_call? call
      if call.call_ended?
        resolve_acw(call) if call.agent.present? && account.features?(:freshfone_acw)
        trigger_cost_job(call)
        update_pinged_agent_response_and_info(call)
      end
    end
  end

  def after_commit(call)
    return unless call.safe_send(:transaction_include_action?, :update)
    initiate_subscription_actions(call) if
      call.previous_changes[:total_duration] && trial?
    if call_not_ringing?(call)
      Resque.remove_delayed(Freshfone::NotificationFailureRecovery, {:account_id => call.account.id, :call_id => call.id})  if call.noanswer? || call.inprogress? || call.queued?
    end
  end

	private
    def call_not_ringing?(call)
      call.previous_changes[:call_status].last != Freshfone::Call::CALL_STATUS_HASH[:default] if call.previous_changes[:call_status].present?
    end

		def initialize_data_from_params(freshfone_call)
			params = freshfone_call.params || {}
			freshfone_call.business_hour_call = freshfone_call.freshfone_number.working_hours?
			freshfone_call.call_sid = params[:CallSid] if freshfone_call.call_sid.blank?
		end

    def update_caller_data(freshfone_call)
      params = freshfone_call.params || {}
      if freshfone_call.blocked?
        blocked_customer_data(freshfone_call, params) 
      else
        freshfone_call.incoming? ? incoming_customer_data(freshfone_call, params) : 
        outgoing_customer_data(freshfone_call, params)
      end
    end

		def incoming_customer_data(freshfone_call, params)
      options = {
          :number  => params[:From],
          :country => params[:FromCountry],
          :state   => params[:FromState],
          :city    => params[:FromCity]
      }
      freshfone_call.caller = build_freshfone_caller(freshfone_call, options)
		end

		def blocked_customer_data(freshfone_call, params)
      options = {
          :number  => params[:From],
          :country => params[:FromCountry],
          :state   => params[:FromState],
          :city    => params[:FromCity]
      }
      freshfone_call.caller = build_freshfone_caller(freshfone_call, options)
      freshfone_call.call_status = Freshfone::Call::CALL_STATUS_HASH[:blocked]
		end

		def outgoing_customer_data(freshfone_call, params)
      options = {
          :number  => params[:PhoneNumber] || params[:To],
          :country => params[:ToCountry].blank? ? params[:phone_country] : params[:ToCountry],
          :state => params[:ToState],
          :city  => params[:ToCity]
      }
      freshfone_call.caller = build_freshfone_caller(freshfone_call, options)
		end

		def set_customer_on_ticket_creation(freshfone_call)
			return unless freshfone_call.notable_id_changed?
			notable_item = freshfone_call.notable
			freshfone_call.customer = (freshfone_call.ticket_notable?) ? 
																 notable_item.requester : 
																 notable_item.notable.requester
		end
		
		def build_freshfone_caller(freshfone_call, options)
      return freshfone_call.caller if options[:number].blank? #empty caller returned set it to null.
      account = freshfone_call.account
      caller  = account.freshfone_callers.find_or_initialize_by_number(options[:number])
      options.delete(:country) if options[:country].blank? # sometimes empty country is updated.
      caller.update_attributes(options)
      caller
    end

    def update_pinged_agent_status(call)
      set_agent_response(call.account_id, call.id, call.user_id, :accepted)
    end

    def add_cost_job(freshfone_call)
      cost_params = { :account_id => freshfone_call.account_id, :call =>  freshfone_call.id}
      Resque::enqueue_at(2.minutes.from_now, Freshfone::Jobs::CallBilling, cost_params) 
      Rails.logger.debug "FreshfoneJob for sid : #{freshfone_call.call_sid} :: dsid : #{freshfone_call.dial_call_sid} :: Call Id :#{cost_params[:call]}"
    end

    def trigger_cost_job(freshfone_call)
      return if freshfone_call.call_cost.present?
      add_cost_job freshfone_call
    end

    def publish_new_call_status(freshfone_call)
      account = freshfone_call.account
      case freshfone_call.call_status
        when Freshfone::Call::CALL_STATUS_HASH[:queued]
          trigger_queued_call_publish(freshfone_call, account)
        when Freshfone::Call::CALL_STATUS_HASH[:completed]
          if (freshfone_call.call_status_was == Freshfone::Call::CALL_STATUS_HASH[:queued])
            trigger_dequeued_call_publish(freshfone_call, account) 
          else  
            trigger_active_call_end_publish(freshfone_call, account)
          end
        when Freshfone::Call::CALL_STATUS_HASH[:'in-progress']
          trigger_new_active_call_publish(freshfone_call, account) unless (freshfone_call.call_status_was == Freshfone::Call::CALL_STATUS_HASH[:'on-hold'])
        else
          trigger_dequeued_call_publish(freshfone_call, account) if (freshfone_call.call_status_was == Freshfone::Call::CALL_STATUS_HASH[:queued])
      end
    end

    def publish_new_warm_transfer(freshfone_call)
      account = freshfone_call.account
      trigger_new_active_call_publish(freshfone_call, account) if 
                   freshfone_call.call_status == Freshfone::Call::CALL_STATUS_HASH[:'on-hold'] && freshfone_call.previous_changes[:call_status].blank?
    end

    def trigger_queued_call_publish(freshfone_call, account)
      publish_queued_call(freshfone_call, freshfone_call.account)
    end

    def trigger_dequeued_call_publish(freshfone_call, account)
      publish_dequeued_call(freshfone_call, account)
    end

    def trigger_new_active_call_publish(freshfone_call, account)
      publish_new_active_call(freshfone_call,account) 
    end

    def trigger_active_call_end_publish(freshfone_call, account)
      publish_active_call_end(freshfone_call,account)
    end

    def create_call_metrics(freshfone_call)
      freshfone_call.create_call_metrics ({:account => freshfone_call.account})
    end
    
    def initiate_trial_trigger_worker(freshfone_call)
      trigger_params = { :account_id => freshfone_call.account_id, :call => freshfone_call.id }
      Freshfone::TrialCallTriggerWorker.perform_async(trigger_params)
    end

    def initiate_tracker(freshfone_call) #Will be used only for freshfone trial customers initially #Add condition to check for freshfone trial
      if freshfone_call.inprogress?
        return if [Freshfone::Call::CALL_STATUS_HASH[:'in-progress'], Freshfone::Call::CALL_STATUS_HASH[:'on-hold']].include?(freshfone_call.call_status_was)
        Freshfone::TrackerWorker.perform_async(freshfone_call.id, :connect, Time.now)
      elsif freshfone_call.completed?
        return if (freshfone_call.call_status_was == Freshfone::Call::CALL_STATUS_HASH[:completed])
        Freshfone::TrackerWorker.perform_async(freshfone_call.id, :disconnect, Time.now)
      end
    end

    def initiate_subscription_actions(call)
      freshfone_subscription.add_to_calls_minutes(call.call_type, call.total_duration)
      initiate_trial_trigger_worker(call)
    end

    def ongoing_child_call?(call)
      call.inprogress? && call.user_id.present? && (
        call.incoming? || !call.is_root?) # checking not root for outgoing child
    end

    def resolve_acw(call)
      move_to_acw_state(call) if acw_preconditions?(call)
    end

    def acw_preconditions?(call)
      single_leg_outgoing_or_completed?(call) && !transferred?(call) &&
        !on_app_or_mobile?(call) && !warm_transferred?(call)
    end

    def single_leg_outgoing_or_completed?(call)
      call.outgoing_root_call? || call.completed?
    end

    def on_app_or_mobile?(call)
      call.meta.android_or_ios? || (!call.outgoing_root_call? &&
       call.meta.available_on_phone?)
    end

    def move_to_acw_state(call)
      freshfone_user = call.agent.freshfone_user
      freshfone_user.acw!
      trigger_acw_timer(call)
    end

    def transferred?(call)
      call.children.present? && call.children.last.call_status.in?(
        Freshfone::Call::ONGOING_CALL_STATUS)
    end

    def warm_transferred?(call)
      call.supervisor_controls.inprogress_warm_transfer_calls.present?
    end

    def outgoing_meta_buildable?(call)
      call.outgoing? && call.is_root? && call.params[:device_info].present? &&
      	call.meta.blank?
    end

    def build_outgoing_browser_meta(call)
      call.create_meta(account_id: call.account_id,
        device_type: Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:browser])
    end

    def disconnected?(call)
      call.outgoing_root_call? && call.dial_call_sid_changed? &&
        Freshfone::Call::COMPLETED_CALL_STATUS.include?(call.call_status)
    end

    def trigger_disconnect_job(call)
      disconnect_params = { call_id: call.id, enqueued_time: Time.now }
      jid = Freshfone::CallTerminateWorker.perform_async(disconnect_params)
      Rails.logger.info "Freshfone Call Terminate Worker: Job-id: #{jid}, Account ID: #{call.account_id}, Worker Params: #{disconnect_params.inspect}"
    end

    def update_pinged_agent_response_and_info(call)
      call_meta = call.meta
      return if call_meta.blank?
      pinged_meta = get_and_clear_redis_meta(call)
      Rails.logger.info "Meta Data :: Account :: #{call.account_id}  :: Call :: #{call.id} :: #{pinged_meta.inspect}"
      agent_response = pinged_meta.first
      agent_info = pinged_meta.second['agent_info']
      call_meta.pinged_agents.each do |agent|
        redis_response = agent_response[agent[:id].to_s]
        agent[:response] = Freshfone::CallMeta::PINGED_AGENT_RESPONSE_HASH[
          redis_response.to_sym] if redis_response.present?
      end
      call_meta.meta_info = { agent_info: agent_info } if agent_info.present?
      call_meta.save!
    end
end
