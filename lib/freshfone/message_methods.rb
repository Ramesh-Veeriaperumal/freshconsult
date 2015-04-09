module Freshfone::MessageMethods
	
	MESSAGE_TYPES = {
		:recording => 0,
		:uploaded_audio => 1,
		:transcript => 2
	}

	def audio
		@audio ||= attachments.select {|a| a.id == attachment_id }.first unless attachment_id.blank?
	end
	
	def attachment_name
		audio.content_file_name unless audio.blank?
	end
	
	def attachment_url
		audio.expiring_url("original", 3600) unless audio.blank?
	end
	
	def has_recording_url?
		!recording_url.blank?
	end
	
	def has_attachment?
		(!attachment_id.blank? || has_new_attachment?(new_attachment_reference))
	end
	
	MESSAGE_TYPES.each_pair do |k, v|
		define_method("#{k}?") do
			message_type == v
		end
	end
	
	private
		def has_message?
			(recording? && has_recording_url?) ||
			(uploaded_audio? && has_attachment?) ||
			(transcript? && !message.blank?)
		end

		def has_valid_size?
			(transcript? && (message.length <= 4096) )
		end
end