class Freshfone::CallInitiator
	include FreshfoneHelper
	include Freshfone::NumberMethods
	include Freshfone::CallsRedisMethods

	VOICEMAIL_TRIGGERS = ['no-answer', 'busy', 'failed']
	BATCH_SIZE = 10

	attr_accessor :params, :current_account, :current_number, :call_flow, :batch_call,
								:below_safe_threshold, :queued, :missed_call
	delegate :available_agents, :busy_agents, :welcome_menu, :root_call,
					 :outgoing_transfer, :numbers, :read_welcome_message,:transfered, :register_call_transfer,
					 :calls_count, :outgoing?, :non_business_hour_calls?, :to => :call_flow, :allow_nil => true
	delegate :number, :record?, :read_voicemail_message, :read_queue_message, :read_non_business_hours_message, 
					 :read_non_availability_message,	:voice_type, :to => :current_number
	
	def initialize(params={}, current_account=nil, current_number=nil, call_flow=nil)
		self.params = params
		self.current_account = current_account
		self.current_number = current_number
		self.call_flow = call_flow
	end
	
	# agent class -> Freshfone::User
	def connect_caller_to_agent(agents=nil)
		set_calls_beyond_threshold
		twiml_response do |r|
			read_welcome_message(r) unless primary_leg? 
			timeout = current_number.rr_timeout if current_number.round_robin?  #10 secs = min 5 rings.
			agents_to_be_called = process_in_batch(agents || available_agents)
			r.Dial :callerId => outgoing_transfer ? params[:To] : params[:From],
						 :record => record?, :action => status_url,
						 :timeout => timeout || current_number.ringing_time, #nil will default to 30 secs
						 :timeLimit => time_limit do |d|
				agents_to_be_called.each { |agent| agent.call_agent_twiml(d, forward_url(agent), current_number, update_user_presence_url(agent))}
			end
			r.Redirect force_termination_url, :method => "POST"
		end
	end

	def connect_caller_to_numbers
		twiml_response do |r|
			numbers.each do |number|
				r.Dial :callerId => params[:From], :record => record?, 
				:timeLimit => 1800,
				:timeout => current_number.ringing_time,
							 :action => direct_dial_url(number) do |d|
					d.Number number, :url => direct_dial_success(number)
				end
			end
		end
	end

	def initiate_outgoing
		set_calls_beyond_threshold
		twiml_response do |r|
			r.Dial :callerId => number, :record => record?, :timeout => 60,
						 :action => outgoing_url, :timeLimit => time_limit do |d|
				d.Number params[:PhoneNumber], :url => update_user_presence_url
			end
		end
	end

	def initiate_recording
		twiml_response do |r|
			r.Say 'Record your message after the tone.', :voice => voice_type
			r.Record :action => record_message_url, :finishOnKey => "#", :maxLength => 300
			r.Redirect "#{force_termination_url}?record=true", :method => "POST"
		end
	end

	def add_caller_to_queue(hunt_options)
		return non_availability if queue_overloaded? or queue_disabled?
		@hunt = hunt_options
		twiml_response do |r|
			read_welcome_message(r)
			r.Enqueue current_account.name, :waitUrl => enqueue_url, :action => quit_queue_url
			r.Redirect force_termination_url, :method => "POST"
		end
	end

	def make_transfer_to_agent(target_agent , call_back = false)
		agent = get_target_agent(target_agent, call_back)
		register_call_transfer(agent.user_id, params[:outgoing])
		return dial_to_agent(agent, call_back)
	end

	def initiate_voicemail(type = "default")
		if current_number.voicemail_active
			twiml_response do |r|
				read_voicemail_message(r, type)
				r.Record :action => quit_voicemail_url, :finishOnKey => '#', :maxLength => 300
				r.Redirect "#{status_url}?force_termination=true", :method => "POST"
			end
	 	else
		  Twilio::TwiML::Response.new.text
		end
	end
	
	def block_incoming_call
		twiml_response do |r|
			r.Reject :reason => "busy"
		end
	end

	def return_non_business_hour_call
		twiml_response do |r|
			read_non_business_hours_message(r)
			if current_number.voicemail_active
				read_voicemail_message(r, "default")
				r.Record :action => quit_voicemail_url, :finishOnKey => '#'
			end
			r.Redirect "#{status_url}?force_termination=true", :method => "POST"			
		end
	end

	def return_non_availability
		twiml_response do |r|
			read_welcome_message(r) unless primary_leg?
			read_non_availability_message(r)
			if current_number.voicemail_active
				read_voicemail_message(r, "default")
				r.Record :action => quit_voicemail_url, :finishOnKey => '#'
			end
			r.Redirect "#{status_url}?force_termination=true", :method => "POST"			
		end
	end
	alias_method :non_availability, :return_non_availability

	private
		def twiml_response
			twiml = Twilio::TwiML::Response.new do |r|
				yield r
			end
			twiml.text
		end

		def queue_overloaded?
			queue_sid = current_account.freshfone_account.queue
      queue = current_account.freshfone_subaccount.queues.get(queue_sid)
      queue.present? and (queue.current_size > max_queue_size)
		end

		def outgoing_url
			"#{status_url}?agent=#{params[:agent]}"
		end

		def status_url
			params = [:batch_call, :below_safe_threshold].inject({}) do |params, condition_sym|
				send(condition_sym) ? params.merge({ condition_sym => true }) : params
			end
			params.blank? ? "#{host}/freshfone/call/status" : "#{host}/freshfone/call/status?#{params.to_query}"
		end

		def force_termination_url
			"#{host}/freshfone/call/status?force_termination=true"
		end
		
		def direct_dial_url(number)
			"#{host}/freshfone/call/status?direct_dial_number=#{CGI.escape(format_number(number))}"
		end
		
		def direct_dial_success(number)
			"#{host}/freshfone/call/direct_dial_success?direct_dial_number=#{CGI.escape(format_number(number))}"
		end

		def update_user_presence_url(agent = nil)
			agent_params = agent.present? ? "?agent=#{agent.user_id}" : ""
			"#{host}/freshfone/call/in_call#{agent_params}"
		end

		def forward_url(agent)
			"#{update_user_presence_url(agent)}&forward=true"
		end

		def record_message_url
			"#{host}/freshfone/device/record?agent=#{params[:agent]}&number_id=#{params[:number_id]}"
		end

		def enqueue_url
			"#{host}/freshfone/queue/enqueue#{hunt_params}" 
		end

		def quit_queue_url
			"#{host}/freshfone/queue/hangup#{hunt_params}&force_termination=true"
		end

		def hunt_params
			"?hunt_type=#{@hunt[:type]}&hunt_id=#{@hunt[:performer]}"
		end

		def quit_voicemail_url
			"#{host}/freshfone/voicemail/quit_voicemail"
		end

		def transfer_call_status_url(call_back)
			"#{status_url}?transfer_call=true&target_agent=#{params[:id] || params[:source_agent]}&source_agent=#{params[:source_agent]}&call_back=#{call_back}&outgoing=#{params[:outgoing]}"
		end

		def call_transfer_success_url (agent, current_user, call_back)
			"#{host}/freshfone/call/call_transfer_success?agent=#{agent.user_id}&transfer_call=true&source_agent=#{current_user}&call_back=#{call_back}"
		end

		def forward_call_url (agent, current_user, call_back)
			"#{call_transfer_success_url(agent, current_user, call_back)}&forward=true"
		end

		def process_in_batch(agents)
			current_batch_agents = current_number.round_robin? ? agents.slice!(0, 1) : agents.slice!(0, BATCH_SIZE)
			if agents.present?
				Rails.logger.debug "Batch Call started for call_sid ==> #{params[:CallSid]} ::
account_id ==> #{current_account.id} :: no of agents called ==> #{agents.size + BATCH_SIZE}" if params[:batch_call].blank?
				self.batch_call = true
				key = FRESHFONE_AGENTS_BATCH % { :account_id => current_account.id, :call_sid => params[:CallSid] }
				agent_ids = agents.collect(&:id).to_json
				set_key(key, agent_ids, 600)
			end
			current_batch_agents
		end

		def time_limit
			# 15 minutes on throttled and 4 hours by default
			current_account.freshfone_credit.below_safe_threshold? ? 900 : 14400
		end

		def set_calls_beyond_threshold
			return unless current_account.freshfone_credit.below_safe_threshold?
			key = FRESHFONE_CALLS_BEYOND_THRESHOLD % { :account_id => current_account.id }
			set_key(key, calculate_calls_count)
			self.below_safe_threshold = true
		end

		def primary_leg?
			transfered or queued or missed_call or params[:batch_call]
		end
		
		def calculate_calls_count
			# First four bits for outgoing(0b0000xxxx), next four bits for incoming(0bxxxx0000)
			incoming = calls_count >> 4
			outgoing = calls_count & 15
			if outgoing?
				outgoing += 1
			else
				incoming += 1
			end
			(incoming << 4) + outgoing
		end

		def format_number(number)
			@number = GlobalPhone.parse(number).international_string
		end

		def get_target_agent(target_agent, call_back)
			@agent = current_account.freshfone_users.online_agents.find_by_user_id(target_agent) 
			@agent = current_account.freshfone_users.find_by_user_id(params[:source_agent]) if @agent.blank? || call_back
			return @agent
		end

		def dial_to_agent (agent, call_back)
			Twilio::TwiML::Response.new do |r|
				r.Dial :callerId => params[:outgoing] ? params[:To] : params[:From],
						 :record => current_number.record?, 
						 :action => transfer_call_status_url(call_back),
						 :timeout => current_number.ringing_time,
						 :timeLimit => time_limit do |d|
					agent.call_agent_twiml(d, forward_call_url(agent, params[:source_agent], call_back),
							 current_number, call_transfer_success_url(agent, params[:source_agent], call_back))
					end
			end.text
		end
end