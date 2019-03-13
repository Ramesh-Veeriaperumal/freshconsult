class CompanyFilterValidation < FilterValidation
  attr_accessor :include, :include_array, :letter, :type, :ids

  validates :include, data_type: { rules: String }, on: :index
  validates :letter, custom_inclusion: { in: ApiConstants::ALPHABETS }, on: :index
  validates :type, custom_inclusion: { in: CompanyConstants::ACTIVITY_TYPES }, on: :activities
  validates :ids, data_type: { rules: Array, allow_nil: false },
                  array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param } },
                  custom_length: { maximum: Solution::Constants::COMPANIES_LIMIT, message_options: { element_type: :values } }
  validate :validate_include, if: -> { errors[:include].blank? && include }

  def initialize(request_params, item = nil, allow_string_param = true)
    self.skip_hash_params_set = true
    request_params[:ids] = request_params[:ids].split(',') if request_params.key?(:ids)
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
