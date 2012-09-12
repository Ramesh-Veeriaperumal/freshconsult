class Notifications::Message
	
	def initialize(message, badge, type, sender=User.current)
		@header = {
			:timestamp => timestamp,
			:type => type,
			:sender => sender.display_name,
		}
		@body = {
			:message => message,
			:icon_class => badge
		}	
	end


	def encoded
		{ :header => header, :body => body }.to_json
	end

	def created_at
		Time.now
	end

	private
		def timestamp
			"#{self.created_at.to_s}"
		end

end
