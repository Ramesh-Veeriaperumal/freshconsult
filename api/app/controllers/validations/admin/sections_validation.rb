module Admin
  class SectionsValidation < ApiValidation
    include Admin::TicketFieldHelper

    attr_accessor :id, :ticket_field_id, :tf, :correct_mapping, :section_data

    validate :invalid_ticket_field, if: -> { tf.blank? }
    validate :dynamic_section?, if: :default_ticket_type?
    validate :multi_dynamic_section?, if: :custom_dropdown?
    validate :invalid_section, if: -> { update_or_destroy? && section_data.blank? }
    validate :correct_mapping?, if: -> { tf.present? && section_data.present? }, on: :destroy

    def initialize(request_params, item, options)
      self.id = request_params[:id]
      self.ticket_field_id = request_params[:ticket_field_id]
      self.tf = options[:tf]
      self.section_data = item
      self.correct_mapping = options[:correct_mapping]
      super(request_params, section_data)
    end

    private

      def invalid_ticket_field
        errors[:invalid_ticket_field] << :invalid_ticket_field
      end

      def invalid_section
        errors[:invalid_section] << :invalid_section
      end

      def correct_mapping?
        if correct_mapping.blank?
          errors[:invalid_mapping] << :invalid_ticket_field_section_mapping
          error_options[:invalid_mapping] = { section_id: id, ticket_field_id: ticket_field_id }
        end
      end
  end
end
