class CustomDashboardValidation < ApiValidation
  attr_accessor :name, :accessible_attributes, :widgets_attributes, :id, :group_ids, :access_type
  
  validates :name, :accessible_attributes, :access_type, :widgets_attributes, presence: true, on: :create
  validates :group_ids, required: true, on: :create, if: -> { group_access_dashboard }
  validates :name, data_type: { rules: String }
  validates :accessible_attributes, data_type: { rules: Hash }
  validates :access_type, data_type: { rules: Integer }, custom_inclusion: { in: Dashboard::Custom::CustomDashboardConstants::DASHBOARD_ACCESS_TYPE.values }
  validates :group_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0 } }
  validates :widgets_attributes, data_type: { rules: Array }
  validate :validate_widgets, if: -> { widgets_attributes && errors[:widgets_attributes].blank? }

  def initialize(request_params, item = nil, allow_string_param = false)
    if request_params[:accessible_attributes].present?
      @access_type = request_params[:accessible_attributes][:access_type]
      @group_ids = request_params[:accessible_attributes][:group_ids] if group_access_dashboard
    end
    super(request_params, item, allow_string_param)
  end

  def validate_widgets
    widgets_errors = []
    widgets_attributes.each do |widget|
      widget_validator = WidgetValidation.new(widget, nil)
      widgets_errors << widget_validator.errors.full_messages unless widget_validator.valid?
    end
    errors[:widgets] = 'is invalid' if widgets_errors.present?
  end

  def group_access_dashboard
    access_type == Dashboard::Custom::CustomDashboardConstants::DASHBOARD_ACCESS_TYPE[:groups]
  end

end
