module ContactsCompaniesConcern
  extend ActiveSupport::Concern

  def assign_avatar
    given_avatar_id = params[cname][:avatar_id]
    @item.avatar = @delegator.draft_attachments.first if given_avatar_id.present?
  end

  def mark_avatar_for_destroy
    avatar_id = @item.avatar.id if params[cname].key?('avatar_id') && @item.avatar
    @item.avatar_attributes = { id: avatar_id, _destroy: 1 } if avatar_id.present? &&
                                                                avatar_id != params[cname][:avatar_id]
  end
end
