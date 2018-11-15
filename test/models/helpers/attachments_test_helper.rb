module AttachmentsTestHelper

	def central_publish_attachment_pattern(attachment)
		ret_hash = {
			id:	attachment.id,
			account_id: attachment.account_id,
			description: attachment.description,
			file_name: attachment.content_file_name,
			content_type: attachment.content_content_type,
			file_size: attachment.content_file_size,
			attachable_id: attachment.attachable_id,
			attachable_type: attachment.attachable_type,
			attachment_url: attachment_url,
			created_at: attachment.created_at.try(:utc).try(:iso8601),
			updated_at: attachment.updated_at.try(:utc).try(:iso8601)
		}	
	end

	def attachment_url
    attachment.inline_image ? "" : attachment.attachment_url_for_api(true, :original, 1.day)
  end
end