class JwtPayloadValidation < ApiValidation
  attr_accessor :payload, :expiry

  validates :payload, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.help_widget_payload_format } }, required: true, on: :help_widget
  validate :validate_exp, if: -> { errors.blank? }, on: :help_widget

  def initialize(request_params, expiry)
    super(request_params)
    @payload = request_params
    @expiry = expiry
  end

  def help_widget_payload_format
    {
      name: {
        data_type: {
          rules: String,
          required: true,
          message: :missing_or_blank
        },
        custom_length: {
          maximum: ApiConstants::MAX_LENGTH_STRING
        }
      },
      email: {
        data_type: {
          rules: String,
          required: true,
          message: :missing_or_blank
        },
        custom_format: {
          with: ApiConstants::EMAIL_VALIDATOR,
          accepted: :'valid email address'
        },
        custom_length: {
          maximum: ApiConstants::MAX_LENGTH_STRING
        }
      },
      exp: {
        data_type: {
          rules: Integer,
          required: true,
          message: :missing_or_blank
        },
        custom_numericality: {
          only_integer: true,
          greater_than: 0
        }
      }
    }
  end

  private

    def validate_exp
      if Time.at(payload[:exp]).utc > Time.now.utc + expiry
        errors[:exp] << :expiry_invalid
        error_options[:exp] = { max_time: Time.at(expiry).utc.hour }
      end
    end
end
