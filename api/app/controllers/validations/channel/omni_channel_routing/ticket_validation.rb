module Channel::OmniChannelRouting
  class TicketValidation < ApiValidation
    attr_accessor :agent_id, :current_state

    validates :agent_id, required: true, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }
    validates :current_state, required: true, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.current_state_validation } }

    def current_state_validation
      {
        group_id: { required: true, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param } }
      }
    end
  end
end
