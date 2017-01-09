class FacebookPostDecorator < ApiDecorator
  delegate :id, :post_id, :msg_type, :post_attributes, to: :record

  def initialize(record, options = {})
    super(record)
  end

  def to_hash
    fb_post_hash = {
      id: id,
      post_id: post_id.to_s,
      msg_type: msg_type,
      created_at: record.created_at.try(:utc),
      updated_at: record.updated_at.try(:utc)
    }
    fb_post_hash.merge!(page_name: record.facebook_page.page_name) if ['Helpdesk::Ticket'].include?(record.postable_type)
    fb_post_hash.merge!(post_type: post_attributes[:post_type], can_comment?: record.can_comment?) if record.post?
    fb_post_hash
  end

end