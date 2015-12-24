class ApiTicketFieldFilterValidation < FilterValidation
  attr_accessor :type

  validates :type, custom_inclusion: { in: ApiTicketConstants::FIELD_TYPES }, allow_nil: true
end
