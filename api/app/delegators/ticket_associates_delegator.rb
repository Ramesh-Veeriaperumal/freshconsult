class TicketAssociatesDelegator < BaseDelegator
  validate :related_ticket, on: :unlink
  validate :ticket_for_linking, if: :link_or_bulk_link

  def ticket_for_linking
    errors[:id] << :unable_to_perform if association_type.present? || !can_be_associated?
  end

  def related_ticket
    errors[:id] << :not_a_related_ticket unless related_ticket?
  end

  def link_or_bulk_link
    [:link, :bulk_link].include?(validation_context)
  end
end
