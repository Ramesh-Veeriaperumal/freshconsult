class AccountValidation < ApiValidation
  attr_accessor :cancellation_feedback, :additional_cancellation_feedback
  
  validates :cancellation_feedback, presence: true, on: :cancel
  validates :cancellation_feedback, data_type: { rules: String, allow_nil: false }, on: :cancel
  validates :additional_cancellation_feedback, data_type: { rules: String, allow_nil: true }, on: :cancel
end