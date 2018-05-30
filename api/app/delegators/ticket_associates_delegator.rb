class TicketAssociatesDelegator < BaseDelegator
  validate :ticket_for_linking, on: :bulk_link

  def ticket_for_linking
    errors[:id] << :unable_to_perform if association_type.present? || !can_be_associated?
  end

end
