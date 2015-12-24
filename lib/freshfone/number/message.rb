class Freshfone::Number::Message
	include Freshfone::MessageMethods
	attr_accessor :message, :message_type, :attachment_id, :recording_url, :type,
								:parent, :group_id
	delegate :account, :has_new_attachment?, :attachments, :voice_type, :to => :parent

	DEFAULT_MESSAGE = {
		:on_hold_message => "All agents are busy attending to other customers. Please hold the line or press * at any point to leave a voicemail",
		:non_availability_message => "Our agents are unavailable to take your call right now",
		:voicemail_message => "Please leave a message at the tone",
		:non_business_hours_message => "You have reached us outside of our hours of operation"
	}

	def initialize(message)
		message.each_pair do |k,v|
			instance_variable_set('@' + k.to_s, v)
		end
	end

	def as_json(options=nil)
		{ :message => message,
			:messageType => message_type,
			:attachmentId => attachment_id,
			:attachmentName => CGI.escapeHTML(attachment_name || ""),
			:attachmentUrl => CGI.escapeHTML(attachment_url || ""),
			:recordingUrl => CGI.escapeHTML(recording_url || ""),
			:type => type,
			:group_id => group_id
		}
	end
  
  def to_json(options=nil)
		as_json(options).to_json
	end
	
	def validate
		parent.errors.add(:base,I18n.t('flash.freshfone.number.blank_message', 
															{:num_type => type.to_s.humanize})) unless has_message?
		parent.errors.add(:base, I18n.t('flash.freshfone.number.invalid_message_length', 
															{:num_type => type.to_s.humanize})) if has_invalid_size?
	end
	
	def to_yaml_properties
		instance_variables.reject{|v| [:@parent].include? v }
	end
	
	def group
		@group ||= begin
			return if group_id.blank? || group_id == 0
			account.groups.find_by_id(group_id)
		end
	end
	
	def speak(xml_builder, loop_count=Freshfone::Number::DEFAULT_WAIT_LOOP)
		if transcript?
			xml_builder.Say message, { :voice => voice_type }
		else
			xml_builder.Play message_url, {:loop => loop_count}
		end
	end

	def message_url
		uploaded_audio? ? attachment_url : recording_url
	end

	private 
		def new_attachment_reference
			type
		end
end
