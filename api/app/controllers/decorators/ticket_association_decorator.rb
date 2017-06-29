class TicketAssociationDecorator < ApiDecorator
  delegate :display_id, :association_type, :status, :requester_id, :responder_id, :subject, to: :record

  def initialize(record)
    super(record)
  end

  def to_hash
    {
      id: display_id,
      requester_id: requester_id,
      responder_id: responder_id,
      subject: subject,
      association_type: association_type,
      status: status
    }
  end
end
