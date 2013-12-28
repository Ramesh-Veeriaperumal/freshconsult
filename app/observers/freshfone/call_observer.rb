class Freshfone::CallObserver < ActiveRecord::Observer
	observe Freshfone::Call

	def before_create(freshfone_call)
		initialize_data_from_params(freshfone_call)
	end

	def before_save(freshfone_call)
		set_customer_on_ticket_creation(freshfone_call) if freshfone_call.customer_id.blank?
	end

	private
		def initialize_data_from_params(freshfone_call)
			params = freshfone_call.params || {}
			freshfone_call.call_sid = params[:CallSid]

			if freshfone_call.blocked?
				blocked_customer_data(freshfone_call, params) 
			else
				freshfone_call.incoming? ? incoming_customer_data(freshfone_call, params) : 
				outgoing_customer_data(freshfone_call, params)
			end
		end

		def incoming_customer_data(freshfone_call, params)
			freshfone_call.customer_number = params[:From]
			freshfone_call.customer_data = {
				:number  => params[:From],
				:city    => params[:FromCity],
				:state   => params[:FromState],
				:country => params[:FromCountry]
			}
		end

		def blocked_customer_data(freshfone_call, params)
			freshfone_call.customer_number = params[:From]
			freshfone_call.call_status = Freshfone::Call::CALL_STATUS_HASH[:blocked]
			freshfone_call.customer_data = {
				:number  => params[:From],
				:city    => params[:FromCity],
				:state   => params[:FromState],
				:country => params[:FromCountry]
			}
		end

		def outgoing_customer_data(freshfone_call, params)
			freshfone_call.customer_number = params[:PhoneNumber] || params[:To]
			freshfone_call.customer_data = {
				:number  => params[:PhoneNumber] || params[:To],
				:city    => params[:ToCity],
				:state   => params[:ToState],
				:country => params[:ToCountry].blank? ? params[:phone_country] : params[:ToCountry]
			}
		end

		def set_customer_on_ticket_creation(freshfone_call)
			return unless (freshfone_call.notable_id_changed? && freshfone_call.ticket_notable?)
			freshfone_call.customer = freshfone_call.notable.requester
		end
end