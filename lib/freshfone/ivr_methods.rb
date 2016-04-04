# Has freshfone Ivr related methods

#  initiate incoming changing
#  fallback to parent instead of first
class Freshfone::IvrMethods

	attr_accessor :params, :type, :response_object, :account, :number, :call_flow
	
	delegate	:incoming, :call_users_in_group,
						:call_user_with_id, :call_user_with_number, :set_hunt_options, :to => :call_flow
	
	RESPONSE_TYPE = {
		:twiml_response => :twiml,
		:call_agent => :User,
		:call_group => :Group,
		:call_number => :Number
	}

	def self.trigger_ivr_flow(params, account, number, call_flow)
		new(params, account, number, call_flow).perform_action
	end
	
	def initialize(params={}, account=nil, number=nil, call_flow=nil)
		self.params = params
		self.account = account
		self.number = number
		self.call_flow = call_flow
	end
	
	def perform_action
		(self.type, self.response_object) = ivr_scoper.perform_action(params)
		if call_group?
			call_users_in_group(response_object)
		elsif call_agent?
			call_user_with_id(response_object)
		elsif call_number?
			call_user_with_number(response_object)
		else
			response_object
		end
	end

	RESPONSE_TYPE.each do |k, v|
		define_method("#{k}?") do
			type == v
		end
	end

	private
  
		# Scoper
		def ivr_scoper
			@ivr_scoper ||= ( number.present? ? number.ivr : account.ivrs.find_by_id(params[:id]) )
		end

		def conference?
			call_flow.class.name == 'Freshfone::ConferenceCallFlow' && !twiml_response?
		end
end