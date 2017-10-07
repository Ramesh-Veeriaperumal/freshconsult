class Freshcaller::CallDecorator < ApiDecorator
  delegate :id, :fc_call_id, :recording_status, :ticket_display_id, :note_id, to: :record

  def to_hash
    {
      id: id,
      fc_call_id: fc_call_id,
      recording_status: recording_status,
      ticket_display_id: ticket_display_id,
      note_id: note_id
    }
  end
end
