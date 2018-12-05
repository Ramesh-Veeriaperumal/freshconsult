class BotValidation < ApiValidation
  attr_accessor :id, :name, :avatar, :portal_id, :template_data, :widget_size, :theme_colour, :category_ids, :enable_on_portal, :email_channel, :header, :start_date, :end_date

  validates :id, data_type: { rules: String, required: true, allow_nil: false }, if: :show_or_update
  validates :name, data_type: { rules: String, required: true }, length: { maximum: 25 }, if: :create_or_update
  validate  :avatar_presence, on: :create
  validate  :default_avatar_valid?, if: -> { @avatar && create_or_update }
  validates :avatar, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.avatar_fields_validation } }, allow_nil: false, if: -> { errors[:avatar].blank? && create_or_update }
  validates :header, data_type: { rules: String }, length: { maximum: 100 }, required: true, if: -> { ((validation_context == :update && @header) || (validation_context == :create)) }
  validates :theme_colour, data_type: {rules: String}, custom_format: { with: ApiConstants::COLOR_CODE_VALIDATOR, accepted: :'valid color code' }, required: true, if: -> {((validation_context == :update && @theme_colour) || (validation_context == :create))}
  validates :widget_size, data_type: { rules: String }, custom_inclusion: { in: BotConstants::ALLOWED_SIZES }, required: true, if: -> {((validation_context == :update && @widget_size) || (validation_context == :create))}
  validate  :validate_portal_id, if: :portal_id_dependant_actions
  validates :category_ids, data_type: { rules: Array }, required: true, on: :map_categories
  validates :enable_on_portal, required: true, data_type: { rules: 'Boolean' }, on: :enable_on_portal
  validates :email_channel, data_type: { rules: 'Boolean' }
  validates :start_date, :end_date, date_time: { allow_nil: false }, required: true, on: :analytics
  validate  :validate_time_period, if: -> { errors[:start_date].blank? && errors[:end_date].blank? }, on: :analytics

  PORTAL_ID_DEPENDENT_ACTIONS = %i[new create].freeze
  CREATE_AND_UPDATE_ACTIONS = %i[create update].freeze
  SHOW_AND_UPDATE_ACTIONS = %i[show update].freeze

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
    @item = item
  end

  def portal_id_dependant_actions
    PORTAL_ID_DEPENDENT_ACTIONS.include?(validation_context)
  end

  def show_or_update
    SHOW_AND_UPDATE_ACTIONS.include?(validation_context)
  end

  def create_or_update
    CREATE_AND_UPDATE_ACTIONS.include?(validation_context)
  end

  def validate_portal_id
    errors[:portal_id] << :invalid_portal_id if @portal_id.blank? || @portal_id.to_i <= 0
  end

  def validate_time_period
    errors[:end_date] << :analytics_time_period_invalid if @end_date < @start_date
  end

  def avatar_presence
    errors[:avatar] << :missing_avatar unless @avatar
  end

  def avatar_fields_validation
    if validation_context == :create
      return BotConstants::AVATAR_CREATE_FIELDS
    else
      return BotConstants::AVATAR_UPDATE_FIELDS
    end
  end

  def default_avatar_valid?
    if is_default && @avatar[:avatar_id] && @avatar[:avatar_id] > BotConstants::DEFAULT_AVATAR_COUNT
      errors[:avatar] << :invalid_default_avatar
    end
  end

  def is_default
    (@avatar.has_key?(:is_default) || validation_context == :create) ? @avatar[:is_default] : @item.additional_settings[:is_default]
  end
end
