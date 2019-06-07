# The BaseChoicesTicketFieldValidation class is responsible for custom_dropdown choices validation.
class BaseChoicesTicketFieldValidation < TicketFieldValidation
  attr_accessor :choices

  validates :choices, data_type: { required: true, rules: Array }

  validates :choices, custom_length: { minimum: Helpdesk::Ticketfields::Constants::MIN_CHOICES_COUNT, custom_message: :min_elements, message_options: { min_count: 1 } }

  validates :choices, custom_choices: {}, if: :validate_custom_choices?

  def validate_custom_choices?
    type.include? 'dropdown'
  end
end
