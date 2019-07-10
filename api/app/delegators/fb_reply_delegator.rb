class FbReplyDelegator < ConversationBaseDelegator
  attr_accessor :note_id, :note, :fb_page

  validate :validate_note_id, if: -> { note_id.present? }
  validate :validate_agent_id, if: -> { user_id.present? }
  validate :validate_unseen_replies, on: :facebook_reply, if: :traffic_cop_required?
  validate :validate_page_state, on: :facebook_reply

  def initialize(record, options = {})
    super(record, options)
    @note_id = options[:note_id]
    @fb_page = options[:fb_page]
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
end
