class FbReplyDelegator < BaseDelegator
  attr_accessor :note_id, :note

  validate :validate_note_id, if: -> { note_id.present? }
  validate :validate_agent_id, if: -> { user_id.present? }

  def initialize(record, options = {})
    super(record, options)
    @note_id = options[:note_id]
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
end
