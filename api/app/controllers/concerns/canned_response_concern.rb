module CannedResponseConcern
  extend ActiveSupport::Concern

  def construct_canned_response
    canned_response = params[cname]
    if canned_response[:visibility].present?
      access_attributes = {
        access_type: canned_response.delete(:visibility).to_i,
        group_ids: [],
        user_ids: []
      }
      case access_attributes[:access_type]
      when Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
        access_attributes[:group_ids] = canned_response.delete(:group_ids).map(&:to_i)
      when Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
        access_attributes[:user_ids] = [api_current_user.id]
        canned_response[:folder_id] = current_account.canned_response_folders.personal_folder.first.id
      end
      access_attributes[:id] = @item.helpdesk_accessible.id if update?
      canned_response[:helpdesk_accessible_attributes] = access_attributes
    end
  end

  def build_shared_attachment
    return if params[cname][:attachments].blank?
    params[cname][:attachments].each do |resource|
      attachment_created = @item.account.attachments.create(content: resource, attachable_type: 'Account', attachable_id: current_account.id)
      @item.shared_attachments.build(attachment: attachment_created)
    end
  end

  def build_shared_attachment_with_ids
    return if params[cname][:attachment_ids].blank?
    remove_existing_attachment_ids
    params[cname][:attachment_ids].each do |attachment_id|
      attachment = @item.account.attachments.find(attachment_id.to_i)
      @item.shared_attachments.build(attachment: attachment)
    end
  end

  def remove_existing_attachment_ids
    available_attachment_ids = @item.shared_attachments.pluck(:id)
    params[cname][:attachment_ids] = params[cname][:attachment_ids].map(&:to_i) - available_attachment_ids
  end
end
