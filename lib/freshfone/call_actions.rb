class Freshfone::CallActions
	
	attr_accessor :params, :current_account, :current_number, :outgoing
	
	def initialize(params={}, current_account=nil, current_number=nil)
		self.params = params
		self.current_account = current_account
		self.current_number = current_number
	end

	def register_incoming_call
		current_account.freshfone_calls.create(
			:freshfone_number => current_number,
			:customer => search_customer_with_number(params[:From]),
			:call_type => Freshfone::Call::CALL_TYPE_HASH[:incoming],
			:params => params
		)
	end

	def register_outgoing_call
		current_account.freshfone_calls.create(
			:freshfone_number => current_number,
			:agent => calling_agent,
			:customer => search_customer_with_number(called_number),
			:call_type => Freshfone::Call::CALL_TYPE_HASH[:outgoing],
			:params => params
		)
	end
	
	def register_call_transfer(outgoing=false)
		self.outgoing = outgoing
		return if current_call.blank?

		current_call.root.increment(:children_count).save if build_child.save
	end


	private
		def calling_agent
			current_account.users.technicians.visible.find_by_id(params[:agent])
		end
		
		def build_child
			direction = current_call.direction_in_words
			if current_call.customer_id.blank?
				params[:customer] = search_customer_with_number(params["#{direction}"])
			end
			current_call.build_child_call(params)
		end
		
		def current_call
			@current_call ||= current_account.find_by_call_sid(call_sid)
		end
		
		def called_number
			params[:PhoneNumber] || params[:To]
		end
		
		def call_sid
			outgoing ? params[:ParentCallSid] : params[:CallSid]
		end
		
		def search_customer_with_number(phone_number)
			Freshfone::Search.search_user_with_number(phone_number)
		end

end