class TicketBulkUpdateValidation < ApiValidation
  CHECK_PARAMS_SET_FIELDS = %w(reply).freeze

  attr_accessor :properties, :reply, :statuses, :ticket_fields

  validates :properties, data_type: { rules: Hash, allow_nil: false }
  validates :reply, data_type: { rules: Hash, allow_nil: false }
  validates :reply, custom_absence: { message: :no_reply_privilege }, unless: :has_reply_privilege?

  validate :validate_properties_or_reply_presence, if: -> { errors.blank? }
  validate :validate_ticket_properties, if: -> { errors.blank? && properties.present? }
  validate :validate_reply_hash, if: -> { errors.blank? && reply.present? }

  def initialize(request_params, item = nil, allow_string_param = false)
    super(request_params)
    @statuses = request_params[:statuses]
    @ticket_fields = request_params[:ticket_fields]
  end

  private

    def has_reply_privilege?
      User.current.privilege?(:reply_ticket)
    end

    def validate_properties_or_reply_presence
      errors[:request] << :select_a_field if properties.blank? && reply.blank?
    end

    def validate_ticket_properties
      tkt_validation = TicketValidation.new(properties.merge(statuses: statuses, ticket_fields: ticket_fields), nil)
      tkt_validation.skip_bulk_validations = true
      unless tkt_validation.valid?(:bulk_update)
        @errors = tkt_validation.errors
        (self.error_options ||= {}).merge!(tkt_validation.error_options)
      end
    end

    def validate_reply_hash
      conversation_validation = ConversationValidation.new(reply, nil)
      unless conversation_validation.valid?(:reply)
        @errors = conversation_validation.errors
        (self.error_options ||= {}).merge!(conversation_validation.error_options)
      end
    end
end
