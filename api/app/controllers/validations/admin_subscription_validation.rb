class AdminSubscriptionValidation < ApiValidation
  attr_accessor :include, :include_array, :currency, :agent_seats, :renewal_period, :plan_id

  validates :include, data_type: { rules: String }
  validates :currency, custom_inclusion: { in: Subscription::Currency.currency_names_from_cache }
  validates :renewal_period, required: true, on: :estimate
  validates :renewal_period, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }, custom_inclusion: { in: AdminSubscriptionConstants::VALID_BILLING_CYCLES, ignore_string: :allow_string_param }
  validates :plan_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }
  validates :agent_seats,
            custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }, on: :update
  validates :agent_seats, required: true,
                          custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }, on: :estimate
  validate :validate_include, if: -> { errors[:include].blank? && include }

  def validate_include
    @include_array = include.split(',').map!(&:strip)
    if @include_array.blank? || (@include_array - AdminSubscriptionConstants::ALLOWED_INCLUDE_PARAMS).present?
      errors[:include] << :not_included
      (self.error_options ||= {}).merge!(include: { list: AdminSubscriptionConstants::ALLOWED_INCLUDE_PARAMS.join(', ') })
    end
  end
end
