class ApiSolutions::CategoryFilterValidation < FilterValidation
  attr_accessor :portal_id, :allow_language_fallback

  validates :portal_id, numericality: { only_integer: true, greater_than: 0 }, if: -> { portal_id }
  validates :allow_language_fallback, custom_inclusion: { in: [true, false], ignore_string: :allow_string_param }
end
