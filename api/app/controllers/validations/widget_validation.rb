class WidgetValidation < ApiValidation
  include ::Dashboard::Custom::CustomDashboardConstants

  attr_accessor :id, :widget_type, :name, :config_data, :_destroy, :x, :y, :height, :width

  validates :widget_type, :name, :x, :y, :height, :width, presence: true, on: :create
  validates :id, presence: true, if: -> { _destroy }
  validates :widget_type, :name, :x, :y, :height, :width, presence: true, unless: -> { id }
  validates :id, custom_numericality: { only_integer: true, greater_than: 0 }
  validates :widget_type, data_type: { rules: Integer }, custom_inclusion: { in: WIDGET_MODULES_BY_TOKEN.keys }
  validates :name, data_type: { rules: String }
  validates :x, data_type: { rules: Integer }
  validates :y, data_type: { rules: Integer }
  validates :height, data_type: { rules: Integer }
  validates :width, data_type: { rules: Integer }
  validates :config_data, data_type: { rules: Hash }
  # validate :valid_config_fields?
  validates :_destroy, data_type: { rules: 'Boolean' }

  def initialize(request_params, item = nil, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end

  # def valid_config_fields?
  #   return true if id
  #   # revisit config data
  #   widget_config_fields = "#{WIDGET_MODULES_BY_TOKEN[widget_type]}::CONFIG_FIELDS".constantize
  #   widget_config_fields.all? { |key|  @request_params.include?(key.to_s) }
  # end
end
