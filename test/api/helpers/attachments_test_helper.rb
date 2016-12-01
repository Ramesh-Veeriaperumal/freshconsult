module AttachmentsTestHelper

  def attachment_pattern(expected_output = {}, attachment)
    {
      id: attachment.id,
      content_type: attachment.content_content_type,
      size: attachment.content_file_size,
      name: attachment.content_file_name,
      attachment_url: attachment.attachment_url_for_api,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def create_attachment(params = {})
    @account.attachments.create(:content => params[:content] || fixture_file_upload('/files/attachment.txt', 'text/plain', :binary), 
                                :description => params[:description] || Faker::Lorem.characters(10), 
                                :attachable_type => params[:attachable_type],
                                :attachable_id => params[:attachable_id])
  end

  def create_shared_attachment(item, params = {})
    item.shared_attachments.build.build_attachment(content: params[:content] || fixture_file_upload('/files/attachment.txt', 'text/plain', :binary),
                                                   account_id: @account.id)
    item.save
  end
end
