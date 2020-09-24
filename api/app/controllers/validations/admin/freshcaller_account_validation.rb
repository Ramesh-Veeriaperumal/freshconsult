class Admin::FreshcallerAccountValidation < ApiValidation
  attr_accessor :email, :password, :url, :agent_ids, :settings

  validates :url, data_type: { rules: String, required: true }, on: :link
  validates :email, data_type: { rules: String, required: true },
                    custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' },
                    custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }, on: :link
  validates :password, data_type: { rules: String, required: true }, on: :link
  validates :agent_ids, data_type: { rules: Array, required: false }, on: :update

  validates :settings, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.settings_format } }, allow_nil: true, on: :update

  def initialize(request_params, item = nil, allow_string_param = false)
    super(request_params, item, allow_string_param)
    @settings = request_params[:settings]
  end

  def settings_format
    {
      automatic_ticket_creation: {
        data_type: {
          rules: Hash
        },
        hash: {
          validatable_fields_hash: proc { automatic_ticket_creation_format }
        }
      }
    }
  end

  def automatic_ticket_creation_format
    {
      missed_calls: {
        data_type: {
          rules: 'Boolean'
        }
      },
      abandoned_calls: {
        data_type: {
          rules: 'Boolean'
        }
      },
      connected_calls: {
        data_type: {
          rules: 'Boolean'
        }
      }
    }
  end
end
