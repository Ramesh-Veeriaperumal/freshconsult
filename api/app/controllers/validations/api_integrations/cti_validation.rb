module ApiIntegrations
  class CtiValidation < ApiValidation
    MANDATORY_RESPONDER_FIELDS = [:responder_id, :responder_phone, :responder_unique_external_id, :responder_email].freeze
    MANDATORY_REQUESTER_FIELDS = [:requester_id, :requester_phone, :requester_unique_external_id, :requester_email].freeze
    MANDATORY_RESPONDER_STRING = MANDATORY_RESPONDER_FIELDS.join(', ').freeze
    MANDATORY_REQUESTER_STRING = MANDATORY_REQUESTER_FIELDS.join(', ').freeze

    attr_accessor :requester_id, :requester_phone, :requester_unique_external_id, :requester_email,
                  :responder_id, :responder_phone, :responder_unique_external_id, :responder_email,
                  :call_reference_id, :ticket_id, :call_url, :new_ticket

    validates :requester_phone, :responder_phone, :call_url, :requester_unique_external_id, :requester_email,
              :responder_unique_external_id, :responder_email,
              data_type: {rules: String, allow_nil: false }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }

    validates :responder_id, :requester_id, :ticket_id, custom_numericality: { only_integer: true }, allow_nil: true
    validates :call_reference_id, data_type: { rules: String, required: true }
    validates :new_ticket, data_type: { rules: 'Boolean', allow_nil: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }

    validate :responder_detail_missing
    validate :requester_detail_missing

    private

      def responder_detail_missing
        if MANDATORY_RESPONDER_FIELDS.all? { |x| send(x).blank? && errors[x].blank? }
          errors[:responder_id] << :fill_a_mandatory_field
          error_options[:responder_id] = { field_names: MANDATORY_RESPONDER_STRING }
        end
      end

      def requester_detail_missing
        if MANDATORY_REQUESTER_FIELDS.all? { |x| send(x).blank? && errors[x].blank? }
          errors[:requester_id] << :fill_a_mandatory_field
          error_options[:requester_id] = { field_names: MANDATORY_REQUESTER_STRING }
        end
      end
  end
end
