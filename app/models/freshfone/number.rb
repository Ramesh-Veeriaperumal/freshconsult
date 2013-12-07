class Freshfone::Number < ActiveRecord::Base
	set_table_name :freshfone_numbers
	require_dependency 'freshfone/number/message'

	serialize :on_hold_message
	serialize :non_availability_message
	serialize :voicemail_message

	belongs_to_account
	has_many :freshfone_calls, :class_name => 'Freshfone::Call',
						:foreign_key => :freshfone_number_id, :dependent => :delete_all
	has_one :ivr, :class_name => 'Freshfone::Ivr',
					:foreign_key => :freshfone_number_id, :dependent => :delete
	belongs_to :business_calendar

	has_many :attachments, :as => :attachable, :class_name => 'Helpdesk::Attachment', 
						:dependent => :destroy

	delegate :group_id, :group, :to => :ivr
	attr_accessor :attachments_hash, :address_required
	attr_protected :account_id

	MESSAGE_FIELDS = [:on_hold_message, :non_availability_message, :voicemail_message]
	STATE = { :active => 1, :expired => 2 }
	STATE_BY_VALUE = STATE.invert

	TYPE = [
		[:local, 'local', 1],
		[:toll_free, 'toll_free', 2]
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
	
	validates_presence_of :account_id
	validates_presence_of :number, :presence => true
	validates_inclusion_of :queue_wait_time,  :in => [ 2, 5, 10, 15 ] #Temp options
	validates_inclusion_of :max_queue_length, :in => [ 0, 3, 5, 10 ] #Temp options
	validates_inclusion_of :voice, :in => VOICE_HASH.values,
		:message => "%{value} is not a valid voice type"
	validates_inclusion_of :state, :in => STATE.values,
		:message => "%{value} is not a valid state"
	validates_inclusion_of :number_type, :in => TYPE_HASH.values,
		:message => "%{value} is not a valid number_type"
	validate_on_create :validate_purchase
	validate_on_update :validate_settings, :validate_attachments, :unless => :deleted_changed?
	validates_uniqueness_of :number, :scope => :account_id

	named_scope :filter_by_number, lambda {|from, to| {
		:conditions => ["number in (?, ?)", from, to] }
	}
	named_scope :expired, :conditions => { :state => 2 }


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

	def voice_type
		male_voice? ? VOICE_TYPE_HASH[:male] : VOICE_TYPE_HASH[:female]
	end

	def to_json
		MESSAGE_FIELDS.map do |msg_type|

			if self[msg_type].blank?
				{ :type => msg_type }
			else
				self[msg_type].parent = self
				self[msg_type]
			end
		end.to_json
	end

	def non_business_hour_calls?
    business_calendar.blank?
  end
	
	def has_new_attachment?(type)
		attachments_hash.has_key?(type)
	end
	
	def after_find
		assign_number_to_message
	end

	def self.find_due(renew_at = Time.now)
		find(:all, :conditions => { :state => STATE[:active], 
											 :next_renewal_at => (renew_at.beginning_of_day .. renew_at.end_of_day) })
	end

	def renew
		begin
			if account.freshfone_credit.renew_number(rate)
				update_attributes(:next_renewal_at => 
								self.next_renewal_at.advance(:months => 1))
			else
				update_attributes(:state => STATE[:expired],
					:next_renewal_at => self.next_renewal_at.advance(:months => 1))
				FreshfoneNotifier.deliver_number_renewal_failure(account, self.number)
			end
		rescue Exception => e
			puts "Number Renewal failed for Account : #{account.id} : \n #{e}"
			FreshfoneNotifier.deliver_number_renewal_failure(account, self.number)
		end
	end

	def queue_wait_time_in_minutes
		queue_wait_time.minutes.from_now
	end
	
	def read_voicemail_message(xml_builder, type)
		current_message(type).speak(xml_builder) unless current_message(type).blank?
	end
	
	def read_queue_message(xml_builder)
		on_hold_message.speak(xml_builder) unless on_hold_message.blank?
	end
	
	def message_changed?
		on_hold_message_changed? || non_availability_message_changed? || voicemail_message_changed? 
	end

	def unused_attachments
		attachments.reject{ |a| inuse_attachment_ids.include? a.id }
	end

	private

		def set_renewal_date
			self.next_renewal_at = 1.month.from_now
		end

		def valid_credit_and_country?
			number_country = Freshfone::Cost::NUMBERS[country]
			credit = account.freshfone_credit
			type = TYPE_STR_REVERSE_HASH[number_type]
			return false if credit.blank? or number_country.blank?
			credit.available_credit >= number_country[type]
		end

		def validate_settings
			MESSAGE_FIELDS.each do |message|
				return if self[message].blank?
				self[message].parent = self; 

				case message
					when :voicemail_message
						self[message].validate unless !voicemail_active
					when :on_hold_message
						self[message].validate unless max_queue_length===0
					else
						self[message].validate
				end
			end
		end

		def validate_attachments
			(attachments || []).each do |a|
				errors.add_to_base(I18n.t('freshfone.admin.invalid_attachment',
					{ :name => a.content_file_name })) unless a.audio?
			end
		end

		def validate_purchase
			return if valid_credit_and_country?
			errors.add_to_base(I18n.t('freshfone.admin.numbers.cannot_purchase'))
		end

		def assign_number_to_message
			MESSAGE_FIELDS.each {|type| self[type].parent = self unless self[type].blank? }
		end
		
		def current_message(type)
			["offline", "non_business_hours"].include?(type) ? non_availability_message :
																													voicemail_message
		end

		def inuse_attachment_ids
			MESSAGE_FIELDS.map { |message| self[message].attachment_id unless self[message].blank? }.compact
		end

end