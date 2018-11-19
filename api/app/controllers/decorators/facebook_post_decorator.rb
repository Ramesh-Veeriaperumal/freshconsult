class FacebookPostDecorator < ApiDecorator
  delegate :id, :post_id, :msg_type, :post_attributes, to: :record

  def public_hash
    fb_post_hash = { id: post_id.to_s, type: msg_type }
    # This is to convert post_type to enum. Post_type will be post, comment, reply_to_comment
    fb_post_hash[:post_type] = Facebook::Constants::CODE_TO_POST_TYPE[post_attributes[:post_type]] if record.post?
    fb_post_hash[:page] = FacebookPageDecorator.new(record.facebook_page).public_hash if ['Helpdesk::Ticket'].include?(record.postable_type)
    fb_post_hash
  end

  def to_hash
    fb_post_hash = {
      id: id,
      post_id: post_id.to_s,
      msg_type: msg_type,
      created_at: record.created_at.try(:utc),
      updated_at: record.updated_at.try(:utc)
    }
    fb_post_hash[:fb_page] = fb_page_info if ['Helpdesk::Ticket'].include?(record.postable_type)
    if record.post?
      fb_post_hash[:post_type] = post_attributes[:post_type]
      fb_post_hash[:can_comment?] = record.can_comment?
    end
    fb_post_hash
  end

  def fb_page_info
    FacebookPageDecorator.new(record.facebook_page).to_hash
  end
end
