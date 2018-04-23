class CustomerNoteFilterValidation < FilterValidation
  attr_accessor :next_id

  validates :next_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }
end
