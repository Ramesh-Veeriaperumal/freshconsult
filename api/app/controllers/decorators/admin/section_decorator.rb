class Admin::SectionDecorator < ApiDecorator
  include Admin::TicketFieldHelper

  delegate :id, :label, :ticket_field_id, to: :record

  def initialize(record, options)
    super(record, options)
  end

  def to_hash
    construct_sections(record.ticket_field, record).first
  end
end
