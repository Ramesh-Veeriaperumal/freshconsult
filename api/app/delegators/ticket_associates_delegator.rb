class TicketAssociatesDelegator < BaseDelegator
  validate :ticket_for_linking, on: :bulk_link
  validate :ticket_for_unlinking, on: :bulk_unlink

  def ticket_for_linking
    errors[:id] << :unable_to_perform if association_type.present? || !can_be_associated?
  end

  def ticket_for_unlinking
    errors[:id] << :unable_to_perform unless related_ticket?
  end

end
