class Freshfone::Option
  include Freshfone::CallValidator
  include Freshfone::SubscriptionsUtil
  include Freshfone::NumberValidator

  attr_accessor :performer, :performer_id, :respond_to_key, :menu, 
								:attachment_id, :performer_number
  delegate :ivr, :find_attachment, :account, :is_root?, :perform_call,
					 :handle_menu_jumps, :to => :menu
	
	PERFORMER_TYPE = [
		[ :call_agent,	I18n.t('freshfone.admin.ivr.call_agent'),	:User ],
		[ :call_group,	I18n.t('freshfone.admin.ivr.call_agent_group'),	:Group ],
		[ :call_number,	I18n.t('freshfone.admin.ivr.call_number'),	:Number ],
		[ :jump_to,	    I18n.t('freshfone.admin.ivr.jump_to'),	:IVR ],
		[ :return_back,	I18n.t('freshfone.admin.ivr.back_to_menu'),	:Back ],
	]
	
	PERFORMER_TYPE_HASH = Hash[*PERFORMER_TYPE.map { |i| [i[0], i[2]] }.flatten]
	VALID_PERFORMER_TYPE = PERFORMER_TYPE.map { |i| i[2] }
	PERFORMER_TYPE_OPTIONS = PERFORMER_TYPE.map { |i| [i[1], i[2]] }

  def initialize(option)
    option.each_pair do |k,v|
      instance_variable_set('@' + k.to_s, v)
    end
  end
	
	def audio
		@audio ||= find_attachment(attachment_id) unless attachment_id.blank?
	end
	
	def perform_action
		is_performer_caller? ? perform_call(menu, performer, active_performer) : handle_menu_jumps(self)
	end
	
	def attachment_url
		audio.expiring_url("original", 3600) unless audio.blank?
	end
	
	def attachment_name
		audio.content_file_name unless audio.blank?
	end

	def as_json(options=nil)
		{ :respondToKey => respond_to_key,
			:performerType => performer,
			:performerId => performer_id,
			:performerNumber => performer_number,
			:optionId => respond_to_key
		}
	end
  
  def to_json(options=nil)
		as_json(options).to_json
	end
	
	def validate
		unless has_valid_performer_type?
			ivr.errors.add(:base, t('freshfone.admin.ivr.invalid_performer_type'))
		end
		ivr.errors.add(:base, I18n.t('freshfone.admin.trial.numbers.ivr.direct_dial')) if call_number? && in_trial_states?
		ivr.errors.add(:base, I18n.t('freshfone.admin.ivr.invalid_number',
																				{ :menu => menu.menu_name })) if invalid_performer_number?
		ivr.errors.add(:base, I18n.t('freshfone.admin.ivr.restricted_country',
																				{ :menu => menu.menu_name })) if restricted_performer_number?
		ivr.errors.add(:base, I18n.t('freshfone.admin.ivr.invalid_jump_to',
															{ :menu => menu.menu_name })) if has_invalid_jump_to?
	end
	

	def is_performer_caller?
		call_group? || call_agent? || call_number?
	end

	def is_performer_menu?
		jump_to? || return_back?
	end
	
	PERFORMER_TYPE_HASH.each_pair do |k, v|
		define_method("#{k}?") do
			performer.to_sym == v
		end
	end
	
	private
		# validation to check if child has jump to
		def has_invalid_jump_to?
			jump_to? && !is_root?
		end
	
		def has_valid_performer_type?
			VALID_PERFORMER_TYPE.include?(performer.to_sym)
		end
		
		def invalid_performer_number?
			call_number? && fetch_country_code(performer_number).blank?
		end

		def restricted_performer_number?
			call_number? && !invalid_performer_number? &&
				!authorized_country?(CGI.escapeHTML(performer_number),account)
		end
		
		def active_performer
			call_number? ? performer_number : performer_id
		end

end