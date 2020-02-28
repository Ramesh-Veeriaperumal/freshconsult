class AdvancedTicketingDelegator < BaseDelegator
  include Admin::AdvancedTicketing::FieldServiceManagement::CustomFieldValidator
  include Admin::AdvancedTicketing::FieldServiceManagement::Constant

  validate :feature_toggle_enabled?, on: :create
  validate :validate_feature_absence, on: :create
  validate :validate_fsm, on: :create
  validate :validate_feature_presence, on: :destroy

  def initialize(record, options = {})
    @item = record
    options.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
    super(record, options)
  end

  def feature_toggle_enabled?
    unless Account.current.safe_send("#{@feature}_toggle_enabled?")
      errors[:name] << :require_feature
      @error_options[:feature] = @feature
    end
  end

  def validate_feature_absence
    if Account.current.safe_send("#{@feature}_enabled?") || (@item && Account.current.installed_applications.find_by_application_id(@item.id))
      errors[:name] << :feature_exists
      @error_options[:feature] = @feature
    end
  end

  def validate_feature_presence
    unless Account.current.safe_send("#{@feature}_enabled?")
      errors[:id] << :feature_unavailable
      @error_options[:feature] = @feature
    end
  end

  def validate_fsm
    return true unless @feature.to_sym == FSM_FEATURE

    # Plan based validation was done in validate_params.
    errors[:name] << :fsm_only_on_mint_ui unless Account.current.has_feature?(:disable_old_ui)
    errors[:name] << :feature_exists if Account.current.has_feature?(:field_service_management)
    errors[:name] << :fsm_custom_fields_not_available unless fsm_artifacts_available?

    @error_options[:feature] = @feature unless errors[:name].empty?
    errors
  end

end
