class ConversationFilterValidation < FilterValidation
  attr_accessor :include, :include_array, :order_by, :parent, :parent_id

  validates :include, data_type: { rules: String }, on: :ticket_conversations
  validate :validate_include, if: -> { errors[:include].blank? && include }
  validates :order_by, custom_inclusion: { in: ConversationConstants::ORDER_BY }
  validates :parent, data_type: { rules: 'Boolean', ignore_string: :allow_string_param }
  validates :parent_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }

  def initialize(request_params, item = nil, allow_string_param = true)
    super(request_params, item, allow_string_param)
  end

  def validate_include
    @include_array = include.split(',').map!(&:strip)
    unless @include_array.present? && (@include_array - ConversationConstants::SIDE_LOADING).blank?
      errors[:include] << :not_included
      (self.error_options ||= {}).merge!(include: { list: ConversationConstants::SIDE_LOADING.join(', ') })
    end
  end
end
