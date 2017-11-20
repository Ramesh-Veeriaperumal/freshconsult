require 'business_calendar_ext/association'
class Freshfone::Number < ActiveRecord::Base
  self.primary_key = :id
	include Mobile::Actions::Freshfone
	self.table_name =  :freshfone_numbers
	include BusinessCalendarExt::Association

	require_dependency 'freshfone/number/message'

	serialize :on_hold_message #Queue Message
	serialize :non_availability_message
	serialize :non_business_hours_message
	serialize :voicemail_message
	serialize :wait_message #Message that plays after the welcome message
	serialize :hold_message

	belongs_to_account
	has_many :freshfone_calls, :class_name => 'Freshfone::Call',
						:foreign_key => :freshfone_number_id, :dependent => :delete_all
	has_one :ivr, :class_name => 'Freshfone::Ivr',
					:foreign_key => :freshfone_number_id, :dependent => :delete
	has_many :freshfone_number_groups, :class_name => "Freshfone::NumberGroup",
  					:dependent => :delete_all, :foreign_key => :freshfone_number_id
	belongs_to :business_calendar
	belongs_to :freshfone_caller_id, :class_name => "Freshfone::CallerId", :foreign_key => :caller_id

	has_many :attachments, :as => :attachable, :class_name => 'Helpdesk::Attachment', 
						:dependent => :destroy

	delegate :group_id, :group, :read_welcome_message, :to => :ivr
	attr_accessor :attachments_hash, :address_required, :skip_in_twilio
	attr_protected :account_id
  after_find :assign_number_to_message
  after_create :assign_number_to_message

  #on_hold_message is not HOLD message. it is queue message. Should be renamed
	MESSAGE_FIELDS = [:on_hold_message, :non_availability_message, :voicemail_message, :non_business_hours_message, :wait_message, :hold_message]
	STATE = { :active => 1, :expired => 2 }
	STATE_BY_VALUE = STATE.invert
	
	DEFAULT_WAIT_MUSIC = "http://com.twilio.music.guitars.s3.amazonaws.com/Pitx_-_Long_Winter.mp3"
	DEFAULT_QUEUE_MUSIC = "http://com.twilio.music.guitars.s3.amazonaws.com/Pitx_-_A_Thought.mp3"
	DEFAULT_RINGING_MUSIC = "http://assets1.freshdesk.com/assets/cdn/ringing.mp3"
	DEFAULT_WAIT_LOOP = 1

	TYPE = [
		[:local, 'local', 1],
		[:toll_free, 'toll_free', 2],
		[:mobile, 'mobile', 3]
	]
	TYPE_HASH = Hash[*TYPE.map { |i| [i[0], i[2]] }.flatten]
	TYPE_STR_HASH = Hash[*TYPE.map { |i| [i[1].to_s, i[2]] }.flatten]
	TYPE_STR_REVERSE_HASH = Hash[*TYPE.map { |i| [i[2], i[1]] }.flatten]
	
	# Format: [symbol, twilio_type, display_name, value_for_select_tag]
	VOICE = [
		[ :male, "man", I18n.t('freshfone.admin.ivr.male'), 0 ],
		[ :female, "woman", I18n.t('freshfone.admin.ivr.female'),  1 ] 
	]

	VOICE_OPTIONS = VOICE.map { |i| [ i[2], i[3] ] }
	VOICE_HASH = Hash[*VOICE.map { |i| [ i[0], i[3] ] }.flatten]
	VOICE_TYPE_HASH = Hash[*VOICE.map { |i| [ i[0], i[1] ] }.flatten]
	VOICEMAIL_STATE = { :on => 1, :off => 0}
	VOICEMAIL_STATE_BY_VALUE = VOICEMAIL_STATE.invert
	
	HUNT_TYPE = { :simultaneous => 1, :round_robin => 2 }
	RECORDING_VISIBILITY = {:public_recording => true, :private_recording => false}
	ALL_NUMBERS = "0" #Used in Call History and Reports for filtering
	MIN_RINGING_TIME = 10
	MIN_RR_TIMEOUT = 10
	MAX_RINGING_TIME = 999
	PORT_STATE = {:port_in => 1, :port_away => 2}

	validates_presence_of :account_id
	validates_presence_of :number, :presence => true
	validates_inclusion_of :queue_wait_time,  :in => [ 1, 2, 3, 4, 5, 10, 15 ] #Temp options
	validates_inclusion_of :max_queue_length, :in => [ 0, 3, 5, 10 ] #Temp options
	validates_inclusion_of :voice, :in => VOICE_HASH.values,
		:message => "%{value} is not a valid voice type"
	validates_inclusion_of :state, :in => STATE.values,
		:message => "%{value} is not a valid state"
	validates_inclusion_of :number_type, :in => TYPE_HASH.values,
		:message => "%{value} is not a valid number_type"
	validate :validate_purchase, on: :create
	validate :validate_settings, :validate_attachments, :validate_name, :unless => :deleted_changed?, on: :update
	validate :validate_queue_position_message, :if => :queue_position_preference, on: :update
	validates_inclusion_of :rr_timeout, :in => MIN_RR_TIMEOUT..MAX_RINGING_TIME
	validates_inclusion_of :ringing_time, :in => MIN_RINGING_TIME..MAX_RINGING_TIME
	validates_uniqueness_of :number, :scope => :account_id
	validate :validate_port
	scope :filter_by_number, lambda {|from, to| {
		:conditions => ["number in (?, ?)", from, to] }
	}
	scope :expired, :conditions => { :state => 2 }
	scope :numbers_with_groups, :include => :freshfone_number_groups
	scope :active_number, lambda{ |number| {
			:conditions => {:number => number, :state => STATE[:active] }
		}
	}


	VOICE_HASH.each_pair do |k, v|
		define_method("#{k}_voice?") do
			voice == v
		end
	end

	TYPE_HASH.each_pair do |k, v|
		define_method("#{k}?") do
			number_type == v
		end
	end	

	HUNT_TYPE.each do |k, v|
		define_method("#{k}?") do
			hunt_type == v
		end
	end

	RECORDING_VISIBILITY.each do |k, v|
		define_method("#{k}?") do 
			recording_visibility == v
		end
	end

	def voice_type
		male_voice? ? VOICE_TYPE_HASH[:male] : VOICE_TYPE_HASH[:female]
	end
	
	def as_json(opts ={})
    if opts.blank?
      MESSAGE_FIELDS.map do |msg_type|

        if self[msg_type].blank?
          { :type => msg_type }
        else
          self[msg_type].parent = self
          self[msg_type].as_json
        end
      end
    else
      super(opts)
    end
	end

	def number_name
		self.name.blank? ? self.number : self.name
	end

	def non_business_hour_calls?
    business_calendar.blank?
  end
  alias_method :non_business_hour_calls, :non_business_hour_calls?
	
	def has_new_attachment?(type)
		attachments_hash.has_key?(type)
	end
	
	def self.find_due(renew_at = Time.now)
		where("next_renewal_at <= ? AND state = ? AND deleted = ?", renew_at.end_of_day, STATE[:active], false)
	end

	def self.find_trial_account_due(renew_at = Time.now)
		Freshfone::Number.all(:include => {:account => :subscription}, 
			:conditions => ['freshfone_numbers.state = ? AND freshfone_numbers.deleted = ? AND freshfone_numbers.next_renewal_at BETWEEN ? and ? AND subscriptions.state = ?',
											STATE[:active], false, renew_at.beginning_of_day, renew_at.end_of_day, 'trial'])
	end

	def renew
		begin
			next_renewal = self.next_renewal_at.advance(:months => 1) - 1.day
			deduce_credit
			update_attributes(:next_renewal_at => next_renewal)
		rescue Exception => e
			puts "Number Renewal failed for Account : #{account.id} : \n #{e}"
			notify_number_renewal_failure(e)
			# FreshfoneNotifier.deliver_number_renewal_failure(account, self.number)
		end
	end

	def insufficient_renewal_amount?
		credit = account.freshfone_credit
		credit.available_credit < rate
	end

	def queue_wait_time_in_minutes
		queue_wait_time.minutes.from_now
	end
	
	def read_voicemail_message(xml_builder, type)
		voicemail_message.speak(xml_builder) unless voicemail_message.blank?
	end
	
	def read_queue_message(xml_builder)
		on_hold_message.speak(xml_builder) unless on_hold_message.blank?
	end

	def play_hold_message(xml_builder)
		hold_message.speak(xml_builder, 50) unless hold_message.blank? # loop 50 
	end

	def read_non_availability_message(xml_builder)
		non_availability_message.speak(xml_builder) unless non_availability_message.blank?
	end

	def read_non_business_hours_message(xml_builder)
		non_business_hours_message.speak(xml_builder) unless non_business_hours_message.blank?
	end

	def play_wait_message(xml_builder)
		wait_message.speak(xml_builder, 5) unless wait_message.blank?
	end
	
	def message_changed?
		on_hold_message_changed? || non_availability_message_changed? || 
		voicemail_message_changed? || non_business_hours_message_changed?
	end

	def unused_attachments
		attachments.reject{ |a| inuse_attachment_ids.include? a.id }
	end

	def ringing_duration
		round_robin? ? rr_timeout : ringing_time
	end

	def working_hours?
    (non_business_hour_calls? or within_business_hours?)
  end

  def within_business_hours?
    default_business_calendar = business_calendar 
    default_business_calendar.blank? ? 
      (default_business_calendar = Freshfone::Number.default_business_calendar(self)) :
      (Time.zone = default_business_calendar.time_zone)  
    business_hours = Time.working_hours?(Time.zone.now, default_business_calendar)
    ensure
      TimeZone.set_time_zone
  end

	def self.accessible_freshfone_numbers(current_user, freshfone_numbers=[])
		all_numbers = numbers_with_groups
		agent_groups = current_user.agent_groups.collect{|ag| ag.group_id}
		freshfone_numbers = all_numbers.reject { |number|
			number_groups = number.freshfone_number_groups.collect{|group| group.group_id}
			(number_groups.present? && (number_groups&agent_groups).blank?)
		}
		freshfone_numbers
	end

	def can_access_by_agent?(user)
		number_groups = freshfone_number_groups.collect{|group| group.group_id}
		return true if number_groups.blank?
		agent_groups = user.agent_groups.collect{|ag| ag.group_id}
		(number_groups&agent_groups).present?
	end

	def ivr_enabled?
		ivr.ivr_message?
	end

	def self.twilio_number(number_sid, current_account)
		current_account.freshfone_account.twilio_subaccount.incoming_phone_numbers.get(number_sid)
	end

	def private_recording_note?
		private_recording? && record?
	end

	private

		def set_renewal_date
			self.next_renewal_at = 1.month.from_now
		end

		def invalid_credit_and_country
			number_country = Freshfone::Cost::NUMBERS[country]
			credit = account.freshfone_credit
			@available_credit = credit.available_credit
			@number_rate = (number_country || {})[ TYPE_STR_REVERSE_HASH[number_type] ]
			credit.blank? or number_country.blank?
		end

		def sufficient_credits?
			@available_credit >= @number_rate
		end

		def validate_settings
			MESSAGE_FIELDS.each do |message|
				return if self[message].blank?
				self[message].parent = self; 

				case message
					when :voicemail_message
						self[message].validate if voicemail_active
					when :on_hold_message
						self[message].validate unless max_queue_length===0
					when :non_business_hours_message
						self[message].validate unless business_calendar.blank?
					else
						self[message].validate
				end
			end
		end

		def validate_attachments 
			 (attachments || []).each do |a|
			 	if a.id.blank? 
					errors.add(:base,I18n.t('freshfone.admin.invalid_attachment',
						{ :name => a.content_file_name })) unless a.mp3?
				end
			end
		end

		def validate_purchase
			return validate_trial if account.freshfone_account.trial?
			if invalid_credit_and_country
				errors.add(:base,I18n.t('freshfone.admin.numbers.failure_purchase'))
				return false
			end
			errors.add(:base,I18n.t('freshfone.admin.numbers.low_credits')) unless sufficient_credits?
		end

		def assign_number_to_message
			MESSAGE_FIELDS.each {|type| self[type].parent = self unless self[type].blank? }
		end

		def inuse_attachment_ids
			MESSAGE_FIELDS.map { |message| self[message].attachment_id unless self[message].blank? }.compact
		end

		def notify_number_renewal_failure(e)
			message = "The exception is #{e.message} :
									#{e.backtrace.first(5).join(':::')}"
			notification = "Number renewal failed for #{number} in account #{account.id}"
			FreshfoneNotifier.deliver_ops_alert(account, notification, message)
		end

		def validate_name
			errors.add(:base, I18n.t('freshfone.admin.number_settings.name_maxlength')) if (name.present? && name.length > 255 )
		end

		def validate_queue_position_message
			errors.add(:base, "invalid queue position message") if queue_position_message.match(/\{\{queue.position\}\}/).blank?
		end

		def validate_port
			return if !port.present?
			PORT_STATE.values.include?(port) ? true : errors.add(:base, "invalid port state")
		end
		
		def validate_trial
			number_country = Freshfone::Cost::NUMBERS[self.country]
			number_rate = (number_country || {})[Freshfone::Number::TYPE_STR_REVERSE_HASH[number_type]]
			if number_country.blank? || number_rate.blank?
				errors.add :base, I18n.t('freshfone.admin.numbers.failure_purchase')
				return false
			elsif validate_trial_number_restrictions(number_rate)
				errors.add :base, I18n.t('freshfone.admin.trial.request_activation_msg')
				return false
			end
		end

		def validate_trial_number_restrictions(number_rate)
			number_count = Freshfone::Subscription.fetch_number_count(account)
			number_credit = Freshfone::Subscription.fetch_number_credit(account)
			((account.freshfone_numbers.count + 1) > number_count) || (number_rate > number_credit)
		end

		def deduce_credit
			return account.freshfone_subscription.add_to_others_usage(rate) if
				account.freshfone_account.in_trial_states?
			account.freshfone_credit.renew_number(rate, id)
		end
end
