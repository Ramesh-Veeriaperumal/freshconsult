class InstalledApplicationValidation < FilterValidation
  include InstalledApplicationConstants
  
  attr_accessor :name, :event, :payload

  validates :name, data_type: { rules: String, allow_nil: false }
  validates :event, custom_inclusion: { 
      in: EVENTS, required: true 
    }, if: :fetch?

  validates :payload, data_type: {
      rules: Hash, allow_nil: false, required: true
    }, hash: {
      validatable_fields_hash: proc { |x| x.construct_hash_field_validations }
    }, if: :fetch?

  def construct_hash_field_validations
    hash = {}
    if EVENTS_REQUIRES_TYPE_VALUE.include? event
      hash[:type] = { custom_inclusion: { in: ENTITY_TYPES, required: true } }
    end
    if event == INTEGRATED_RESOURCE
      hash[:ticket_id] = { data_type: { rules: Integer, required: true } }
    end
    hash
  end

  private

  def fetch?
    validation_context == :fetch
  end
end
