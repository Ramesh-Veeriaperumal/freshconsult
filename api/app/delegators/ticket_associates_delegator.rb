class TicketAssociatesDelegator < BaseDelegator
  validate :ticket_for_linking, on: :link
  validate :prime_info, on: :prime_association

  def ticket_for_linking
    errors[:id] << :unable_to_perform if association_type.present? || !can_be_associated?
  end

  def prime_info
    errors[:id] << :unable_to_perform unless related_ticket? || child_ticket?
  end
end
