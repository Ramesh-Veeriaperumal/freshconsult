class BotValidation < ApiValidation
  attr_accessor :id, :name, :avatar, :portal_id, :template_data, :category_ids, :enable_on_portal, :header, :start_date, :end_date

  validates :id, data_type: { rules: String, required: true, allow_nil: false }, if: :show_or_update
  validates :name, data_type: { rules: String, required: true }, length: { maximum: 25 }, if: :create_or_update
  validates :avatar, data_type: { rules: Hash, allow_nil: false, required: true }, on: :create
  validates :template_data, data_type: { rules: Hash, allow_nil: false }, if: :create_or_update
  validates :header, data_type: { rules: String }, length: { maximum: 100 }, if: :create_or_update
  validate  :validate_portal_id, if: :portal_id_dependant_actions
  validates :category_ids, data_type: { rules: Array }, required: true, on: :map_categories
  validates :enable_on_portal, required: true, data_type: { rules: 'Boolean' }, on: :enable_on_portal
  validates :start_date, :end_date, date_time: { allow_nil: false }, required: true, on: :analytics
  validate  :validate_time_period, if: -> { errors[:start_date].blank? && errors[:end_date].blank? }, on: :analytics
  validate  :validate_avatar, if: -> { errors[:avatar].blank? && create_or_update }

  PORTAL_ID_DEPENDENT_ACTIONS = %i[new create].freeze
  CREATE_AND_UPDATE_ACTIONS = %i[create update].freeze
  SHOW_AND_UPDATE_ACTIONS = %i[show update].freeze

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
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

  def validate_avatar
    return unless @avatar
    errors[:avatar] << :invalid_avatar unless @avatar[:avatar_id] && @avatar[:url] 
  end
end
