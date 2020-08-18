module CloudFilesHelper
  include Helpdesk::MultiFileAttachment::Util
  
  def build_cloud_files attachment_json
    attachment = ActiveSupport::JSON.decode attachment_json
    decoded_url = attachment['link'] || attachment['url']
    begin
      uri = URI.parse(decoded_url) 
      return {} unless (uri.kind_of?(URI::HTTP) || uri.kind_of?(URI::HTTPS))
    rescue 
      return {}
    end
    filename = attachment['name']
    application_id = attachment['application_id'] || Integrations::Application.find_by_name(attachment['provider']).id
    return {:url => decoded_url, :filename => filename,
            :application_id => application_id}
  end

  def attachment_builder model,normal_attachments,cloud_files_attachments, pre_built_attachments = nil
    build_cloud_files_attachments(model,cloud_files_attachments) if model.respond_to?(:cloud_files)
    build_normal_attachments(model,normal_attachments, pre_built_attachments) if model.respond_to?(:attachments)
    return model
  end

  def build_normal_attachments model, attachments, pre_built_attachments = nil
    (attachments || []).each do |attach|
      model.attachments.build(:content => attach[:resource], :description => attach[:description], :account_id => model.account_id)
    end
    unless pre_built_attachments.blank?
      attachments_to_associate = pre_built_attachments.split(",")
      build_draft_attachments(model, attachments_to_associate.collect{|x| x.to_i})
      attachments_to_associate.each {|attach_id| unmark_for_cleanup(attach_id)}
    end
  end

  def build_cloud_files_attachments model, attachments
    (attachments || []).each do |attachment_json|
        result = build_cloud_files(attachment_json)

        next if result.blank?
        model.cloud_files.build(result)
     end
  end

  def clone_cloud_files_attachments(src, dest)
    src.cloud_files.each do |cloud_file|
      dest.cloud_files.build(url: cloud_file.url,
                             filename: cloud_file.filename,
                             application_id: cloud_file.application_id)
    end
  end

  def build_draft_attachments model, attachment_list
    attachments = if model.is_a?(Solution::FolderMeta)
                    Account.current.attachments.where(id: attachment_list.first, attachable_type: 'Image Upload')
                  elsif Account.current.launched?(:attachments_scope)
                    Account.current.attachments.permissible_drafts(User.current).where(id: attachment_list).limit(50)
                  else
                    Account.current.attachments.where(id: attachment_list, attachable_type: 'UserDraft').limit(50)
                  end

    if model.is_a?(Solution::Draft) || model.is_a?(Solution::Article)
      # size validations for solution_draft and solution-article is done in article_delegator. So it is not needed here
      model.attachments = model.attachments + attachments
    elsif model.is_a?(Solution::FolderMeta)
      model.icon = attachments.first
    else
      existing_size = model.attachments.collect(&:content_file_size).sum
      # attachments.each do |attachment|
      #   if(attachment["resource"] + existing_size < 15.megabyte)
      #     attachment.update_attribute(attachable_type: model.class.name, attachable_id: model.id)
      #     existing_size = existing_size + attachment["resource"]
      #   else
      #     break
      #   end
      # end
      selected_attachments = attachments.select { |x|
        existing_size += x.content_file_size
        existing_size < Account.current.attachment_limit.megabyte
      }
      model.attachments = model.attachments + selected_attachments
    end
  end

end
