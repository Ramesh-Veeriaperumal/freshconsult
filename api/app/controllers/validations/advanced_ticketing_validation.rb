class AdvancedTicketingValidation < ApiValidation
  attr_accessor :name, :id

  validates :name, data_type: { rules: String, required: true }, custom_inclusion: { in: AdvancedTicketingConstants::ADVANCED_TICKETING_APPS }, on: :create
  validates :id, data_type: { rules: String, required: true }, custom_inclusion: { in: AdvancedTicketingConstants::ADVANCED_TICKETING_APPS }, on: :destroy
end