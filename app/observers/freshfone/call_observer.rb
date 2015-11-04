class Freshfone::CallObserver < ActiveRecord::Observer
	observe Freshfone::Call

  include Freshfone::NodeEvents
  include Redis::RedisKeys
  include Redis::IntegrationsRedis

	def before_create(freshfone_call)
		initialize_data_from_params(freshfone_call)
	end

	def before_save(freshfone_call)
		set_customer_on_ticket_creation(freshfone_call) if freshfone_call.customer_id.blank?
    update_caller_data(freshfone_call) if freshfone_call.caller.blank?
	end

  def after_update(freshfone_call)
    publish_new_call_status(freshfone_call) if freshfone_call.call_status_changed?
    trigger_cost_job freshfone_call if freshfone_call.account.features? :freshfone_conference
  end    

	private
		def initialize_data_from_params(freshfone_call)
			params = freshfone_call.params || {}
			freshfone_call.business_hour_call = freshfone_call.freshfone_number.working_hours?
			freshfone_call.call_sid = params[:CallSid]
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

    def call_ended?(freshfone_call)
      [ Freshfone::Call::CALL_STATUS_HASH[:completed], Freshfone::Call::CALL_STATUS_HASH[:busy],
          Freshfone::Call::CALL_STATUS_HASH[:'no-answer'], Freshfone::Call::CALL_STATUS_HASH[:failed],
          Freshfone::Call::CALL_STATUS_HASH[:canceled], Freshfone::Call::CALL_STATUS_HASH[:voicemail] ].include?(freshfone_call.call_status)
    end

    def add_cost_job(freshfone_call)
      cost_params = { :account_id => freshfone_call.account_id, :call =>  freshfone_call.id}
      Resque::enqueue_at(2.minutes.from_now, Freshfone::Jobs::CallBilling, cost_params) 
      Rails.logger.debug "FreshfoneJob for sid : #{freshfone_call.call_sid} :: dsid : #{freshfone_call.dial_call_sid} :: Call Id :#{cost_params[:call]}"
    end

    def trigger_cost_job(freshfone_call)
      return unless freshfone_call.call_status_changed? && freshfone_call.call_cost.blank?
      add_cost_job freshfone_call if call_ended? freshfone_call
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

end
