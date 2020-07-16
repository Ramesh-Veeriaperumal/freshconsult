class ConversationBaseDelegator < BaseDelegator
  include Redis::UndoSendRedis
  def validate_unseen_replies
    traffic_cop_note_id = notable.notes.conversations(nil, 'created_at DESC', 1).pluck(:id).try(:first)
    unseen_notes_exists = (traffic_cop_note_id || 0) > last_note_id
    Rails.logger.info "Traffic cop alert :: #{notable.display_id} :: #{(traffic_cop_note_id || 0)} :: #{last_note_id}"
    if unseen_notes_exists
      errors[:conversation] << :traffic_cop_alert
    elsif undo_send_msg_enqueued?(notable.display_id).present?
      errors[:conversation] << if undo_send_msg_enqueued?(notable.display_id) == User.current.id.to_s
                                 :undo_send_enqueued_agent_alert
                               else
                                 :undo_send_enqueued_alert
                               end
    end
  end

  def traffic_cop_required?
    last_note_id.present? && Account.current.traffic_cop_enabled?
  end
end
