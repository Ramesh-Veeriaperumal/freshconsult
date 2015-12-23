class FilterValidation < ApiValidation
  attr_accessor :per_page, :page

  validates :page, custom_numericality: { allow_nil: true, ignore_string: :allow_string_param, greater_than: 0 }
  validates :per_page, custom_numericality: { allow_nil: true, ignore_string: :allow_string_param,
                                              greater_than: 0, less_than_or_equal_to: ApiConstants::DEFAULT_PAGINATE_OPTIONS[:max_per_page], message: :gt_zero_lt_max_per_page }
end
