class Freshfone::Number::Message
	include Freshfone::MessageMethods
	attr_accessor :message, :message_type, :attachment_id, :recording_url, :type,
								:parent, :group_id
	delegate :account, :has_new_attachment?, :attachments, :voice_type, :to => :parent

	def initialize(message)
		message.each_pair do |k,v|
			instance_variable_set('@' + k.to_s, v)
		end
	end

	def to_json(options=nil)
		{ :message => message,
			:messageType => message_type,
			:attachmentId => attachment_id,
			:attachmentName => attachment_name,
			:attachmentUrl => attachment_url,
			:recordingUrl => recording_url,
			:type => type,
			:group_id => group_id
		}.to_json
	end
	
	def validate
		parent.errors.add_to_base(I18n.t('flash.freshfone.number.blank_message', 
															{:num_type => type.to_s.humanize})) unless has_message?
	end
	
	def to_yaml_properties
		instance_variables.reject{|v| [:@parent].include? v }
	end
	
	def group
		@group ||= account.groups.find_by_id(group_id)
	end
	
	def speak(xml_builder)
		if transcript?
			xml_builder.Say message, { :voice => voice_type }
		else
			xml_builder.Play(uploaded_audio? ? attachment_url : recording_url)
		end
	end
	private 
		def new_attachment_reference
			type
		end

end
