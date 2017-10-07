class TicketTemplateValidation < ApiValidation
  attr_accessor :type, :filter

  validates :type, custom_inclusion: { in: TicketTemplateConstants::ALLOWED_TYPE_VALUES }
  validates :filter, custom_inclusion: { in: TicketTemplateConstants::FILTER_ALLOWED_VALUES }

end