module AttachmentConcern
  extend ActiveSupport::Concern

  def build_normal_attachments(item, attachment_params)
    (attachment_params || []).each do |att|
      item.attachments.build(content: att[:resource], account_id: current_account.id)
    end
  end

  def build_shared_attachments(item, shared_attachments)
    shared_attachments.each do |attach|
      item.attachments.build(content: attach.to_io, account_id: current_account.id)
    end
  end

  def build_cloud_files(item, cloud_files)
    (cloud_files || []).each do |cloud_file|
      cloud_file = { url: cloud_file.url, filename: cloud_file.filename, application_id: cloud_file.application_id } if cloud_file.is_a? Helpdesk::CloudFile
      item.cloud_files.build(cloud_file)
    end
  end
end
