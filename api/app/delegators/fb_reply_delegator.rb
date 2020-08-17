class FbReplyDelegator < ConversationBaseDelegator
  attr_accessor :note_id, :note, :fb_page, :msg_type

  validate :validate_note_id, if: -> { note_id.present? }
  validate :validate_agent_id, if: -> { user_id.present? }
  validate :validate_unseen_replies, on: :facebook_reply, if: :traffic_cop_required?
  validate :validate_page_state, on: :facebook_reply
  validate :validate_attachments, if: -> { @attachment_ids.present? && facebook_post_or_ad_post? }

  def initialize(record, options = {})
    super(record, options)
    @note_id = options[:note_id]
    @fb_page = options[:fb_page]
    @msg_type = options[:msg_type]
  end

  def facebook_post_or_ad_post?
    [Facebook::Constants::FB_MSG_TYPES[1], Facebook::Constants::FB_MSG_TYPES[2]].include?(msg_type)
  end

  def validate_note_id
    @note = notable.notes.find_by_id(note_id)
    if @note.present?
      errors[:note_id] << :unable_to_post_reply unless @note.fb_post.try(:post?) && @note.fb_post.try(:can_comment?)
    else
      errors[:note_id] << :"is invalid"
    end
  end

  def validate_agent_id
    user = Account.current.agents_details_from_cache.find { |x| x.id == user_id }
    errors[:agent_id] << :"is invalid" unless user
  end

  def validate_page_state
    return errors[:fb_page_id] << :invalid_facebook_id unless fb_page
    if fb_page.reauth_required?
      errors[:fb_page_id] << :reauthorization_required
      (error_options[:fb_page_id] ||= {}).merge!(app_name: 'Facebook')
    end
  end

  def validate_attachments
    attachment = Account.current.attachments.find_by_id(@attachment_ids.first)
    if attachment.present?
      attachment_format = attachment.content_content_type
      attachment_size = attachment_size_in_mb(attachment.content_file_size)
      unless ApiConstants::FACEBOOK_ATTACHMENT_CONFIG[:post][:fileTypes].include?(attachment_format)
        errors[:attachment_ids] << :attachment_format_invalid
        (self.error_options ||= {})[:attachment_ids] = { attachment_formats: ApiConstants::FACEBOOK_ATTACHMENT_CONFIG[:post][:fileTypes].join(', ').to_s }
      end
      if ApiConstants::FACEBOOK_ATTACHMENT_CONFIG[:post][:size] < attachment_size
        errors[:attachment_ids] << :file_size_limit_error
        (self.error_options ||= {})[:attachment_ids] = { file_size: ApiConstants::FACEBOOK_ATTACHMENT_CONFIG[:post][:size] }
      end
    end
  end

  private

    def attachment_size_in_mb(size)
      ((size.to_f / 1024) / 1024)
    end
end
