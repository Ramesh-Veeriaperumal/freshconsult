class FilterValidation < ApiValidation
  attr_accessor :per_page, :page

  validates :page, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }
  validates :per_page, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param,
                                              less_than_or_equal_to: ApiConstants::DEFAULT_PAGINATE_OPTIONS[:max_per_page],
                                              custom_message: :per_page_invalid, message_options: { max_value: ApiConstants::DEFAULT_PAGINATE_OPTIONS[:max_per_page] } }
end
