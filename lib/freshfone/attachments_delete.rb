class Freshfone::AttachmentsDelete
	extend Resque::AroundPerform
	@queue = :freshfone_attachments_delete

	def self.perform(args)
		account = Account.current
		attachments = account.attachments.find_all_by_id(args[:attachment_ids])

		attachments.each do |attachment|
			begin
				prefix = "data/helpdesk/attachments/#{Rails.env}/#{attachment.id}/"
                objects = AwsWrapper::S3.find_with_prefix(S3_CONFIG[:bucket], prefix)
				objects.each do |object|
					object.delete if object.key.include?(attachment.content_file_name)
				end
				attachment.delete
			rescue Exception => e
				Rails.logger.debug "Delete attachment failed::::: #{attachment.id}"
				Rails.logger.debug "Error ::::: #{e.inspect}"
			end
		end
	end
end
# VVERBOSE=1 QUEUE=freshfone_attachments_delete rake resque:work