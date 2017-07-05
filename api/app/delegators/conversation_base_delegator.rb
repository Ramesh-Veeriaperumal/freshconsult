class ConversationBaseDelegator < BaseDelegator
  def validate_unseen_replies
    unseen_notes_exists = (notable.notes.visible.last_traffic_cop_note.pluck(:id).try(:first) || 0) > last_note_id
    errors[:conversation] << :traffic_cop_alert if unseen_notes_exists
  end

  def traffic_cop_required?
    last_note_id.present? && Account.current.traffic_cop_enabled?
  end
end
