class CompanyFilterValidation < FilterValidation
  attr_accessor :include, :include_array, :letter, :type

  validates :include, data_type: { rules: String }, on: :index
  validates :letter, custom_inclusion: { in: ApiConstants::ALPHABETS }, on: :index
  validates :type, custom_inclusion: { in: CompanyConstants::ACTIVITY_TYPES }, on: :activities

  validate :validate_include, if: -> { errors[:include].blank? && include }

  def initialize(request_params, item = nil, allow_string_param = true)
    super(request_params, item, allow_string_param)
  end

  def validate_include
    @include_array = include.split(',').map!(&:strip)
    unless @include_array.present? && (@include_array - CompanyConstants::SIDE_LOADING).blank?
      errors[:include] << :not_included
      (self.error_options ||= {}).merge!(include: { list: CompanyConstants::SIDE_LOADING.join(', ') })
    end
  end
end
