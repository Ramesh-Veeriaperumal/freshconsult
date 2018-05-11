module ApiArchiveTicketConstants

  EXPORT_CSV_HASH_FIELDS = %w(ticket_fields contact_fields company_fields archived_tickets).freeze
  EXPORT_FIELDS = %w(format query export_name).freeze | EXPORT_CSV_HASH_FIELDS
  LOAD_OBJECT_EXCEPT = ([:export]).freeze

end
