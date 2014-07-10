class Freshfone::Call < ActiveRecord::Base
	include ApplicationHelper
	set_table_name :freshfone_calls

  serialize :customer_data, Hash

  belongs_to :agent, :class_name => 'User', :foreign_key => 'user_id'
  belongs_to_account
  belongs_to :freshfone_number, :class_name => 'Freshfone::Number'
  belongs_to :ticket, :foreign_key => 'notable_id', :class_name => 'Helpdesk::Ticket'
  belongs_to :note, :foreign_key => 'notable_id', :class_name => 'Helpdesk::Note'

  belongs_to :customer, :class_name => 'User', :foreign_key => 'customer_id'

  belongs_to :notable, :polymorphic => true, :validate => true

  belongs_to :caller, :class_name => 'Freshfone::Caller', :foreign_key => 'caller_number_id'

  has_ancestry :orphan_strategy => :destroy

  before_save   :update_call_changes
  after_commit_on_update :recording_attachment_job, :if => :trigger_recording_job?

  has_one :recording_audio, :as => :attachable, :class_name => 'Helpdesk::Attachment', :dependent => :destroy
  has_one :meta, :class_name => 'Freshfone::CallMeta', :dependent => :destroy

  delegate :number, :to => :freshfone_number
  delegate :name, :to => :agent, :allow_nil => true, :prefix => true
  delegate :name, :to => :customer, :allow_nil => true, :prefix => true
  delegate :group, :to => :meta, :allow_nil => true

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
		[ :blocked, 'blocked', 9 ]
	]

	CALL_STATUS_HASH = Hash[*CALL_STATUS.map { |i| [i[0], i[2]] }.flatten]
	CALL_STATUS_REVERSE_HASH = Hash[*CALL_STATUS.map { |i| [i[2], i[0]] }.flatten]
	CALL_STATUS_STR_HASH = Hash[*CALL_STATUS.map { |i| [i[0].to_s, i[2]] }.flatten]

	CALL_TYPE = [
		[ :incoming,	'incoming',	1 ],
		[ :outgoing,	'outgoing',	2 ]
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
	
	named_scope :active_calls, :conditions => [
		'call_status = ? AND updated_at >= ?', 
		CALL_STATUS_HASH[:'in-progress'], 4.hours.ago.to_s(:db)
	]

	named_scope :filter_by_call_sid, lambda { |call_sid|
		{ :conditions => ["call_sid = ? or dial_call_sid = ?", call_sid, call_sid], :limit => 1 }
	}
	named_scope :include_ticket_number, { 
		:include => [ :ticket, :note, :freshfone_number ] }
	named_scope :include_customer, { :include => [ :customer ] }
	named_scope :include_agent, { :include => [ :agent ] }
	named_scope :newest, lambda { |num| { :limit => num, :order => 'created_at DESC' } }
	named_scope :active_call, :conditions =>  { :call_status => CALL_STATUS_HASH[:default] }, :limit => 1
	named_scope :agent_progress_calls, lambda { |user_id|
		{:conditions => ["user_id = ? and ((call_status = ? and created_at > ? and created_at < ?) or call_status = ?)",
					user_id, CALL_STATUS_HASH[:default], 1.minutes.ago.to_s(:db), Time.zone.now.to_s(:db), CALL_STATUS_HASH[:'in-progress']
				]
		}
	}

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
			(caller || {})[type]
		end
	end
	
	def update_call_details(params)
		self.params = params 
		self.dial_call_sid = params[:DialCallSid]
		self.agent = params[:called_agent] if agent.blank?
		self.recording_url = params[:RecordingUrl] if recording_url.blank?
		self.call_duration = params[:DialCallDuration] || params[:RecordingDuration] if call_duration.blank?
		self.direct_dial_number = params[:direct_dial_number] if ivr_direct_dial?

		update_status(params)
	end

	def update_status(params)
		if params[:DialCallStatus]
			self.call_status = CALL_STATUS_STR_HASH[params[:DialCallStatus]]
		elsif default? and params[:force_termination]
			self.call_status = CALL_STATUS_HASH[:'no-answer']
		end
		self
	end
	
	def location
		[caller_city, caller_state, country_name(caller_country)].reject(&:blank?).join(", ")
	end

	def can_log_agent?
		incoming? && !noanswer?
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
      :requester_id => params[:custom_requester_id] || customer_id,
      :responder => params[:agent],
      :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:phone],
      :subject => ticket_subject,
      :group => group
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
			:source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"],
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

	def self.unbilled(from = 9.hours.ago, to = 3.hours.ago)
		with_exclusive_scope { find(:all, :conditions => 
			[ "call_cost IS NULL and call_status != ? and updated_at BETWEEN ? AND ?", 
				CALL_STATUS_HASH[:blocked], from, to ]) }
	end

	def calculate_cost
		if parent.blank?
			calculator = Freshfone::CallCostCalculator.new({
				:call => id, 
				:call_sid => call_sid,
				:dial_call_sid => dial_call_sid 
			}, account)
			calculator.perform
		end
	end
	
	private
		def child_call_customer_id(params)
			customer_id || (params[:customer] || {})[:id]
		end
		
		def country_name(country_code)
			return country_code if ["US", "USA"].include?(country_code)
      country = Carmen::Country.coded(country_code)
      country ? country.name : nil
		end

		def description_html
			customer_temp = "<b>" + customer_name + "</b> (" + caller_number + ")" if valid_customer_name?
			if voicemail?
				desc = I18n.t('freshfone.ticket.voicemail_ticket_desc', 
					{:customer=> customer_temp || caller_number, :location => location})
			elsif ivr_direct_dial?
				desc = I18n.t('freshfone.ticket.dial_a_number', 
					{:customer=> customer_temp || caller_number, :location => location, 
						:direct_dial_number => params[:direct_dial_number]})
			else
				desc = I18n.t('freshfone.ticket.ticket_desc', 
					{:customer=> customer_temp || caller_number, :location => location, :agent => params[:agent].name, 
						:agent_number => freshfone_number.number})
			end
			desc << "#{params[:call_log]}"
			desc.html_safe
		end

		def valid_customer_name?
			customer_name.present? && (customer_name != caller_number)
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

		def update_call_changes
			@call_model_changes = self.changes.clone
			@call_model_changes.symbolize_keys!
		end

		def trigger_recording_job?
			@call_model_changes.key?(:recording_url) && self.recording_audio.blank?
		end
		
		def recording_attachment_job
			record_params = {
				:account_id => account_id, 
				:call_sid => call_sid,
				:call_id => id,
				:call_duration => call_duration
			}
			record_params.merge!({:voicemail => true}) if (call_status === CALL_STATUS_HASH[:'no-answer'] )
			Resque::enqueue_at(30.seconds.from_now, Freshfone::Jobs::CallRecordingAttachment, record_params) if recording_url
		end
end