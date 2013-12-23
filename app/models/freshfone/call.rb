class Freshfone::Call < ActiveRecord::Base
	include ApplicationHelper
	include Carmen
	set_table_name :freshfone_calls

	serialize :customer_data, Hash

	belongs_to :agent, :class_name => 'User', :foreign_key => 'user_id'
	belongs_to_account
	belongs_to :freshfone_number, :class_name => 'Freshfone::Number'
	belongs_to :ticket, :foreign_key => 'notable_id', :class_name => 'Helpdesk::Ticket'
	belongs_to :note, :foreign_key => 'notable_id', :class_name => 'Helpdesk::Note'

	belongs_to :customer, :class_name => 'User', :foreign_key => 'customer_id'

	belongs_to :notable, :polymorphic => true, :validate => true

	has_ancestry :orphan_strategy => :destroy

	delegate :number, :to => :freshfone_number
	delegate :name, :to => :agent, :allow_nil => true, :prefix => true
	delegate :name, :to => :customer, :allow_nil => true, :prefix => true

	attr_protected :account_id
	attr_accessor :params
	
	CALL_STATUS = [
		[ :default, 'default', 0 ],
		[ :completed,	'completed',	1 ],
		[ :busy,	'busy',	2 ],
		[ :'no-answer',	'missed call',	3 ],
		[ :failed,	'call failed',	4 ],
		[ :canceled,	'call canceled',	5 ],
		[ :queued,	'queued',	6 ],
		[ :ringing,	'ringing',	7 ],
		[ :'in-progress', 'in-progress', 8 ],
		[ :blocked, 'Black listed', 9 ]
	]

	CALL_STATUS_HASH = Hash[*CALL_STATUS.map { |i| [i[0], i[2]] }.flatten]
	CALL_STATUS_REVERSE_HASH = Hash[*CALL_STATUS.map { |i| [i[2], i[0]] }.flatten]
	CALL_STATUS_STR_HASH = Hash[*CALL_STATUS.map { |i| [i[0].to_s, i[2]] }.flatten]

	CALL_TYPE = [
		[ :default, 'default', 0 ],
		[ :incoming,	'incoming',	1 ],
		[ :outgoing,	'outgoing',	2 ],
		[ :transfered,	'transfered',	3 ],
		[ :conference,	'conference',	4 ],
		[ :blocked, 'Black listed', 5 ]
	]

	CALL_TYPE_HASH = Hash[*CALL_TYPE.map { |i| [i[0], i[2]] }.flatten]
	CALL_TYPE_REVERSE_HASH = Hash[*CALL_TYPE.map { |i| [i[2], i[0]] }.flatten]
	
	CALL_DIRECTION_STR = {
		:incoming => "From",
		:outgoing => "To"
	}

	validates_presence_of :account_id, :freshfone_number_id
	validates_inclusion_of :call_status, :in => CALL_STATUS_HASH.values,
		:message => "%{value} is not a valid call status"
	validates_inclusion_of :call_type, :in => CALL_TYPE_HASH.values,
		:message => "%{value} is not a valid call type"

	default_scope :order => "created_at DESC"
	
	named_scope :filter_by_call_sid, lambda { |call_sid|
		{ :conditions => ["call_sid = ? or dial_call_sid = ?", call_sid, call_sid], :limit => 1 }
	}
	named_scope :include_ticket_number, { 
		:include => [ :ticket, :note, :freshfone_number ] }
	named_scope :include_customer, { :include => [ :customer ] }
	named_scope :include_agent, { :include => [ :agent ] }
	named_scope :newest, lambda { |num| { :limit => num, :order => 'created_at DESC' } }
	named_scope :active_call, :conditions =>  { :call_status => CALL_STATUS_HASH[:default] }, :limit => 1


	def self.filter_call(call_sid)
		filter_by_call_sid(call_sid).first
	end
	
	def self.include_all
		self.include_ticket_number.include_customer.include_agent
	end
	
	def self.call_in_progress
		self.active_call.first
	end

	CALL_TYPE_HASH.each_pair do |k, v|
		define_method("#{k}?") do
			call_type == v
		end
	end
	
	CALL_STATUS_HASH.each_pair do |k, v|
		define_method("#{k.to_s.gsub(/\W/, '')}?") do
			call_status == v
		end
	end

	[ :number, :city, :state, :country ].each do |type|
		define_method("caller_#{type}") do
			(customer_data || {})[type]
		end
	end
	
	def direct_dial_number
		(customer_data || {})[:direct_dial_number]
	end
	
	def update_status(params)
		self.params = params 
		self.dial_call_sid = params[:DialCallSid]
		self.call_status = CALL_STATUS_STR_HASH[params[:DialCallStatus]] if params[:DialCallStatus]
		self.agent = params[:called_agent] if agent.blank?
		self.recording_url = params[:RecordingUrl] if recording_url.blank?
		self.call_duration = params[:DialCallDuration] || params[:RecordingDuration] if call_duration.blank?
		self.customer_data[:direct_dial_number] = params[:direct_dial_number] if ivr_direct_dial?
		self
	end
	
	def location
		[caller_city, caller_state, country_name(caller_country)].reject(&:blank?).join(", ")
	end

	def can_log_agent?
		(incoming? || transfered?) && !noanswer?
	end
	
	def ticket_notable?
		notable_type == "Helpdesk::Ticket"
	end
	
	
	def initialize_ticket(params)
		self.params = params
		self.customer_id = params[:custom_requester_id] if customer_id.blank?
		self.notable.attributes = {
			:account_id => account_id,
			:ticket_body_attributes => { :description_html => description_html },
			:email => params[:requester_email],
			:name => requester_name,
			:phone => caller_number,
			:requester_id => customer_id,
			:responder => params[:agent],
			:source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:phone],
			:subject => ticket_subject
		}
		self.notable.build_ticket_and_sanitize
		self
	end
	
	def initialize_notes(params)
		self.params = params
		self.notable.attributes = {
			:account_id => account_id,
			:note_body_attributes => { :body_html => description_html },
			:incoming => true,
			:source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:phone],
			:user => params[:agent],
			:private => false
		}
		self.notable.build_note_and_sanitize
		self
	end
	
	def build_child_call(params)
		children.build(
			:call_type => call_type,
			:account_id => account_id,
			:freshfone_number_id => freshfone_number_id,
			:agent => params[:agent],
			:customer_id => child_call_customer_id(params),
			:params => params
		)
	end
	
	def direction_in_words
		incoming? ? CALL_DIRECTION_STR[:incoming] : CALL_DIRECTION_STR[:outgoing]
	end

	def notable_present?
		notable_id.present? && !included_notable.nil?
	end

	def associated_ticket
		# if notable is_a? 'Helpdesk::Note', notable.notable will return the ticket of that note
		ticket_notable? ? ticket : note.notable
	end
	
	private
		def child_call_customer_id(params)
			customer_id || (params[:customer] || {})[:id]
		end
		
		def country_name(country_code)
			if Country.coded(country_code).name === "United States"
				country_code
			else
		        country= Country.coded(country_code)
		        country ? country.name : nil
		    end
    	end

		def description_html
			customer_temp = "<b>" + customer_name + "</b> (" + caller_number + ")" if valid_customer_name?
			desc = I18n.t('freshfone.ticket.ticket_desc', {:customer=> customer_temp || caller_number, :location => location})
			desc << I18n.t('freshfone.ticket.agent_detail', {:agent => params[:agent].name, :agent_number => freshfone_number.number}) unless voicemail? || ivr_direct_dial?
			desc << I18n.t('freshfone.ticket.dial_a_number', 
							{:direct_dial_number => params[:direct_dial_number]}) if ivr_direct_dial?
			desc << "#{params[:call_log]} #{recording}"
			desc.html_safe
		end

		def valid_customer_name?
			customer_name.present? && (customer_name != caller_number)
		end

		def recording
			self.recording_url = recording_url || params[:RecordingUrl]
			return "" if recording_url.blank?
			"<br /><br /><b><a target=\"_blank\" href=\"#{recording_url}\">
			#{I18n.t('freshfone.ticket.recording')}</a></b><br />
			<audio controls height='100' width='100'>
				<source src=\"#{recording_url}\" type='audio/ogg'>
				<source src=\"#{recording_url}\" type='audio/wav'>
				<source src=\"#{recording_url}.mp3\"> 
			</audio>"
		end

		def requester_name
			 params_requester_name || caller_number
		end

		def ticket_subject
			return I18n.t('freshfone.ticket.voicemail_subject', 
							{:customer => customer_name || caller_number}) if voicemail?
			params_ticket_subject || default_ticket_subject
		end
		
		def voicemail?
			params[:voicemail]
		end
		
		def params_requester_name
			params[:requester_name] unless params[:requester_name].blank?
		end
		
		def params_ticket_subject
			params[:ticket_subject] unless params[:ticket_subject].blank?
		end

		def default_ticket_subject
			I18n.t('freshfone.ticket.default_subject', 
				{:customer => customer_name || requester_name, 
				 :call_date => formated_date(created_at)})
		end
		
		def ivr_direct_dial?
			params[:direct_dial_number]
		end

		def included_notable
			ticket_notable? ? ticket : note
		end
end