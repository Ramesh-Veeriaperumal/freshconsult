class Freshfone::CallInitiator
	include FreshfoneHelper

	VOICEMAIL_TRIGGERS = ['no-answer', 'busy', 'failed']

	attr_accessor :params, :current_account, :current_number, :call_flow
	delegate :available_agents, :busy_agents, :welcome_menu, :root_call,
					 :outgoing_transfer, :numbers, :to => :call_flow, :allow_nil => true
	delegate :number, :record?, :read_voicemail_message, :read_queue_message, :to => :current_number
	
	def initialize(params={}, current_account=nil, current_number=nil, call_flow=nil)
		self.params = params
		self.current_account = current_account
		self.current_number = current_number
		self.call_flow = call_flow
	end
	
	# agent class -> Freshfone::User
	def connect_caller_to_agent
		twiml_response do |r|
			welcome_menu.ivr_message(r) if welcome_menu
			r.Dial :callerId => outgoing_transfer ? params[:To] : params[:From],
						 :record => record?, :action => status_url do |d|
				available_agents.each { |agent| agent.call_agent_twiml(d, forward_call_url(agent)) }
			end
		end
	end
	
	def connect_caller_to_numbers
		twiml_response do |r|
			numbers.each do |number|
				r.Dial :callerId => params[:From], :record => record?,
							 :action => direct_dial_url(number) do |d|
					d.Number number, :url => direct_dial_success(number)
				end
			end
		end
	end

	def initiate_outgoing
		twiml_response do |r|
			r.Dial :callerId => number, :record => record?, :action => outgoing_url do |d|
				d.Number params[:PhoneNumber]
			end
		end
	end

	def initiate_recording
		twiml_response do |r|
			r.Say 'Start recording your message at the beep. Your message will be played back to you once completed.'
			r.Record :action => record_message_url, :finishOnKey => "#", :maxLength => 300
		end
	end

	def add_caller_to_queue(hunt_options)
		@hunt = hunt_options
		twiml_response do |r|
			welcome_menu.ivr_message(r) if welcome_menu
			read_queue_message(r)
			r.Enqueue current_account.name, :waitUrl => enqueue_url, :action => quit_queue_url
		end
	end

	def initiate_voicemail(type = "default")
		twiml_response do |r|
			#skipping IVR on reaching non-responsive office
			# welcome_menu.ivr_message(r) if welcome_menu
			read_voicemail_message(r, type)
			r.Record :action => quit_voicemail_url, :finishOnKey => '#'
		end
	end

	private
		def twiml_response
			twiml = Twilio::TwiML::Response.new do |r|
				yield r
			end
			twiml.text
		end

		def outgoing_url
			"#{status_url}?agent=#{params[:agent]}"
		end

		def status_url
			"#{host}/freshfone/call/status"
		end
		
		def direct_dial_url(number)
			"#{host}/freshfone/call/status?direct_dial_number=#{CGI.escape(number)}"
		end
		
		def direct_dial_success(number)
			"#{host}/freshfone/call/direct_dial_success?direct_dial_number=#{CGI.escape(number)}"
		end

		def forward_call_url(agent)
			"#{host}/freshfone/call/forward?agent=#{agent.user_id}"
		end

		def record_message_url
			"#{host}/freshfone/device/record?agent=#{params[:agent]}"
		end

		def enqueue_url
			"#{host}/freshfone/queue/enqueue#{hunt_params}" 
		end

		def quit_queue_url
			"#{host}/freshfone/queue/hangup#{hunt_params}"
		end

		def hunt_params
			"?hunt_type=#{@hunt[:type]}&hunt_id=#{@hunt[:performer]}"
		end

		def quit_voicemail_url
			"#{host}/freshfone/voicemail/quit_voicemail"
		end
end