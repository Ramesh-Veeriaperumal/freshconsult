module AttachmentsTestHelper
  CLOUD_FILE_IMAGE_URL = 'https://d1z9ryalr1cz6s.cloudfront.net/images/flags/india@2x.png'

  def attachment_pattern(attachment)
    ret_hash = {
      id: attachment.id,
      content_type: attachment.content_content_type,
      size: attachment.content_file_size,
      name: attachment.content_file_name,
      attachment_url: attachment.inline_image? ? attachment.inline_url : String,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    ret_hash[:inline_url] = attachment.inline_url if attachment.inline_image?
    ret_hash[:thumb_url] = attachment.attachment_url_for_api(true, :thumb) if attachment.image? && 
                                                                      !attachment.inline_image?
    ret_hash
  end

  def create_attachment(params = {})
    @account.attachments.create(content: params[:content] || fixture_file_upload('/files/attachment.txt', 'text/plain', :binary),
                                description: params[:description] || Faker::Lorem.characters(10),
                                attachable_type: params[:attachable_type],
                                attachable_id: params[:attachable_id])
  end

  def create_cloud_file_attachment(params = {})
    @account.cloud_files.create(filename: params[:filename] || 'image.jpg',
                                url: CLOUD_FILE_IMAGE_URL,
                                droppable_type: params[:droppable_type],
                                droppable_id: params[:droppable_id],
                                application_id: 20)
  end

  def create_shared_attachment(item, params = {})
    item.shared_attachments.build.build_attachment(content: params[:content] || fixture_file_upload('/files/attachment.txt', 'text/plain', :binary),
                                                   account_id: @account.id)
    item.save
  end

  def attachment_content_hash(attachment)
     attachment.attributes.symbolize_keys.except!(:id, :description, :content_updated_at, :attachable_id, :attachable_type, :created_at, :updated_at)
  end
end
