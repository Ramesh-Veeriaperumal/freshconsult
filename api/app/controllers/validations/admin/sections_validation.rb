module Admin
  class SectionsValidation < ApiValidation
    include Admin::TicketFieldHelper

    attr_accessor :id, :ticket_field_id, :tf, :type, :section_data
    attr_accessor(*SECTION_PARAMS)

    validate :invalid_ticket_field, if: -> { tf.blank? || tf.default? && !default_ticket_type? || !tf.default? && !custom_dropdown? }
    validate :dynamic_section?, if: :default_ticket_type?
    validate :multi_dynamic_section?, if: :custom_dropdown?
    validate :ticket_field_inside_section, if: -> { tf.present? && tf.section_field? }
    validates :label, presence: true, on: :create
    validates :choice_ids, presence: true, on: :create
    validates :label, required: true, data_type: { rules: String },
                      custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING },
                      if: -> { create_or_update? && instance_variable_defined?(:@label) }
    validates :choice_ids, required: true, data_type: { rules: Array },
                           array: { custom_numericality: { only_integer: true, greater_than: 0 } },
                           if: -> { create_or_update? && instance_variable_defined?(:@choice_ids) }

    def initialize(request_params, item, options)
      self.id = request_params[:id]
      self.ticket_field_id = request_params[:ticket_field_id]
      self.tf = options[:tf]
      self.section_data = item
      SECTION_PARAMS.each do |param|
        safe_send("#{param}=", request_params[param]) if request_params.key?(param)
      end
      super(request_params, section_data)
    end

    private

      def invalid_ticket_field
        errors[:invalid_ticket_field] << :invalid_ticket_field
      end

      def ticket_field_inside_section
        errors[:invalid_ticket_field] << :ticket_field_in_section
      end
  end
end
