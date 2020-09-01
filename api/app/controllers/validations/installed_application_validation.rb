class InstalledApplicationValidation < FilterValidation
  include InstalledApplicationConstants
  
  attr_accessor :name, :event, :payload, :configs

  validates :name, data_type: { rules: String, allow_nil: false }
  validates :name, required: true, on: :create
  validates :event, custom_inclusion: { 
      in: EVENTS, required: true 
    }, if: :fetch?

  validates :payload, data_type: {
      rules: Hash, allow_nil: false, required: true
    }, hash: {
      validatable_fields_hash: proc { |x| x.construct_hash_field_validations }
    }, if: :payload_required?
  validates :configs, required: true, data_type: { rules: Hash, allow_nil: false }, on: :create
  validate :validate_configs, on: :create
  validate :validate_freshsales_freshworkscrm_only_events, if: -> { FRESHSALES_ONLY_EVENTS.include?(event) }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
    @item = item
  end

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

  def validate_configs
    if name == 'freshsales' && configs.present? && configs.is_a?(Hash)
      return errors[(INSTALL_CONFIGS_KEYS - configs.keys).join(',').to_sym] << :missing_field unless configs.keys.to_set == INSTALL_CONFIGS_KEYS.to_set
    end
  end

  def validate_freshsales_freshworkscrm_only_events
    unless (@item.application.name == 'freshsales' || @item.application.name == 'freshworkscrm')
      errors[:event] << :"is invalid"
    end
  end

  private

    def payload_required?
      fetch? && EVENTS_REQUIRES_PAYLOAD.include?(event)
    end

    def fetch?
      validation_context == :fetch
    end
end
