class Freshfone::CallObserver < ActiveRecord::Observer
	observe Freshfone::Call

	def before_create(freshfone_call)
		initialize_data_from_params(freshfone_call)
	end

	def before_save(freshfone_call)
		set_customer_on_ticket_creation(freshfone_call) if freshfone_call.customer_id.blank?
    update_caller_data(freshfone_call)
	end

	private
		def initialize_data_from_params(freshfone_call)
			params = freshfone_call.params || {}
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
      return if options[:number].blank?
      account = freshfone_call.account
      caller  = account.freshfone_callers.find_or_initialize_by_number(options[:number])
      options.delete(:country) if options[:country].blank? # sometimes empty country is updated.
      caller.update_attributes(options)
      caller
    end
end