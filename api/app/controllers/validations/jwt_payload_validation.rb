class JwtPayloadValidation < ApiValidation
  attr_accessor :payload, :expiry

  validates :payload, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.help_widget_payload_format } }, required: true, on: :help_widget
  validate :validate_timestamp, if: -> { errors.blank? }, on: :help_widget

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
      timestamp: {
        data_type: {
          rules: String,
          required: true,
          message: :missing_or_blank
        }
      }
    }
  end

  private

    def validate_timestamp
      return errors[:timestamp] << 'invalid_timestamp' unless DateTimeValidator.new(attributes: 'timestamp').validate_date_time(payload[:timestamp])

      timestamp = payload[:timestamp].to_datetime
      return errors[:timestamp] << 'timestamp must be in UTC' unless timestamp.utc?

      expire_at = payload[:timestamp].to_datetime.utc + expiry
      # checks if timestamp is not greater than current time and current time is lesser than expiry time
      if timestamp.utc > Time.now.utc || (Time.now.utc - expire_at) > 0
        errors[:timestamp] << 'invalid_timestamp'
        error_options[:timestamp] = { code: :unauthorized, message: 'timestamp expired or exceeded_current_time' }
      end
    end
end
