class TodoValidation < FilterValidation
  attr_accessor :body, :rememberable_id, :completed, :type, :reminder_at, :item

  CHECK_PARAMS_SET_FIELDS = %w(reminder_at).freeze

  validates :body, data_type: { 
                    rules: String, 
                    allow_nil: false 
                  }
  validates :body, custom_length: { 
                    maximum: TodoConstants::MAX_LENGTH_OF_TODO_CONTENT 
                  }
  validates :completed, data_type: { 
                          rules: 'Boolean' 
                        }
  validates :rememberable_id, custom_numericality: {
                    only_integer: true,
                    ignore_string: :allow_string_param,
                    required: true
                  }, if: -> { 
                              type.present?
                            }
  validates :type, custom_inclusion: { 
                    in: TodoConstants::TODO_REMEMBERABLES, 
                    ignore_string: :allow_string_param, 
                    detect_type: true, 
                    allow_nil: true 
                  }
  validates :reminder_at, custom_absence: {
    message: :only_ticket_type_allowed
  }, unless: :ticket_type?, on: :create

  validates :reminder_at, custom_absence: {
    message: :access_denied,
    code: :access_denied
  }, unless: :valid_user?, on: :update

  validates :reminder_at, custom_absence: {
    message: :only_ticket_type_allowed
  }, unless: :ticket_check?, on: :update

  validate :reminder_time, if: lambda {
    reminder_at.present?
  }
  validates :reminder_at, custom_absence: {
    message: :require_feature_for_attribute,
    code: :inaccessible_field,
    message_options: {
      attribute: 'reminder_at',
      feature: :todos_reminder_scheduler
    }
  }, unless: :todos_reminder_scheduler_enabled?

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
    @item = item
  end

  def reminder_time
    DateTime.iso8601(reminder_at).is_a?(DateTime)
  rescue ArgumentError => e
    errors[:reminder_at] << :datatype_mismatch
    error_options[:reminder_at] = {
      expected_data_type: DateTime,
      prepend_msg: :input_received,
      given_data_type: ExportConstants::DATA_TYPE_MAPPING[reminder_at.class.to_s.to_sym] 
    }
    return false
  end

  private

    def todos_reminder_scheduler_enabled?
      Account.current.todos_reminder_scheduler_enabled?
    end

    def ticket_type?
      type == TodoConstants::TODO_REMEMBERABLES[0]
    end

    def ticket_check?
      item.ticket_id?
    end

    def valid_user?
      User.current.id == item.user_id
    end
end
