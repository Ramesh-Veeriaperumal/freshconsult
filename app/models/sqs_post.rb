class SQSPost < ActiveRecord::Base

	has_no_table
	
	column :account_id, :integer
	column :user, :string 
	column :timestamp, :string
	column :body_html, :string
	column :topic, :string
	column :request_params, :string
	column :domain, :string
	column :attachments, :string
	column :cloud_file_attachments, :string
	column :inline_attachment_ids, :string
	column :portal, :string

	validates_presence_of :body_html

	belongs_to :account

	SQS_CLIENT = $sqs_forum_moderation

	def save(validate = true)
		begin
			if valid?
				set_default_values
				SQS_CLIENT.send_message(self.to_json)
				return true
			end
		rescue Exception => e
			return false
		end
	end

	def set_default_values
		current_account = Account.current
		current_user = User.current
		self[:account_id] = current_account.id
		self[:user] = { :id => current_user.id, :name => current_user.name, :email => current_user.email }
		self[:timestamp] = Time.now.utc.to_f
		self[:domain] = current_account.full_domain
	end
end
