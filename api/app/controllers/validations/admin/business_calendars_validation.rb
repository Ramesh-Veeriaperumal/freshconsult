module Admin
  class BusinessCalendarsValidation < ApiValidation
    include ApiBusinessCalendarConstants
    include Admin::BusinessCalendarHelper

    attr_accessor(*PERMITTED_PARAMS)
    attr_accessor :request_params, :business_calendar
    validates :name, :time_zone, :channel_business_hours, presence: true, on: :create
    validates :channel_business_hours, presence: true, if: -> { instance_variable_defined?(:@channel_business_hours) }, on: :update
    validates :name, data_type: { rules: String, required: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING },
                     if: -> { create_or_update? && instance_variable_defined?(:@name) }
    validates :description, data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING },
                            if: -> { create_or_update? && instance_variable_defined?(:@description) }
    validates :time_zone, custom_inclusion: { in: TIMEZONES }, if: -> { create_or_update? && instance_variable_defined?(:@time_zone) }
    validates :default, custom_inclusion: { in: [true, false] }, if: -> { create_or_update? && instance_variable_defined?(:@default) }
    validates :channel_business_hours, array: { data_type: { rules: Hash },
                                                hash: { business_hours_type: { data_type: { rules: String, required: true } },
                                                        channel: { data_type: { rules: String, required: true } } } },
                                       if: -> { create_or_update? && instance_variable_defined?(:@channel_business_hours) }
    validates :holidays, data_type: { rules: Array },
                         array: { data_type: { rules: Hash },
                                  hash: { date: { data_type: { rules: String, required: true } },
                                          name: { data_type: { rules: String, required: true } } } },
                         if: -> { create_or_update? && instance_variable_defined?(:@holidays) }
    validate :validate_holidays_data, if: -> { create_or_update? && instance_variable_defined?(:@holidays) && errors.blank? }
    validate :validate_channel_business_hours, if: -> { create_or_update? && instance_variable_defined?(:@channel_business_hours)  && errors.blank? }
    validate :check_default_business_calendar, if: -> { validation_context == :destroy }

    def initialize(request_params, item, options)
      self.request_params = request_params
      self.business_calendar = item
      PERMITTED_PARAMS.each do |param|
        safe_send("#{param}=", request_params[param]) if request_params.key?(param)
      end
      super(request_params, nil, options) # sending model attribute as nil to avoid request param definition
    end

    def check_default_business_calendar
      errors[:id] = :default_business_hour_destroy_not_allowed if business_calendar.is_default
    end
  end
end
