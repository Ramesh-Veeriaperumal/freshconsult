# frozen_string_literal: true

class ConversationThreadingDelegator < BaseDelegator
  attr_accessor :parent_id

  validate :validate_parent_id, if: -> { parent_id }

  def initialize(record, options = {})
    @ticket = record
    @parent_id = options[:parent_id]
    super(record, options)
  end

  def validate_parent_id
    parent_note = @ticket.notes.conversations.where(id: parent_id).last
    if parent_note.blank? || (@ticket.facebook? && parent_note.fb_post.blank?)
      errors[:parent_id] << :invalid_value
      error_options[:parent_id] = { value: parent_id }
    end
  end
end
