module Admin
  class SectionsDelegator < BaseDelegator
    include Admin::TicketFieldHelper
    include Admin::TicketFieldFsmHelper

    attr_accessor :record, :ticket_field, :section_data

    validate :empty_section_fields?, if: -> { record.present? }, on: :destroy
    validate :sections_limit, on: :create
    validate :validate_fsm_section, if: lambda {
      (delete_action? && record.options[:fsm].present? && fsm_field_check) ||
      (update_action? && record.options[:fsm].present?)
    }
    validate :validate_section_label, if: -> { create_or_update? && section_data[:label].present? }
    validate :validate_section_choice_ids, if: -> { create_or_update? && section_data[:choice_ids].present? }

    def initialize(record, params, options)
      self.record = record
      self.ticket_field = options[:tf]
      self.section_data = params[:section]
      super(record, params)
    end

    private

      def sections_limit
        errors[:section] << :ticket_field_section_limit if !ticket_field.has_sections? && current_account.sections.group_by(&:ticket_field_id).size == Helpdesk::TicketField::SECTION_LIMIT
      end

      def empty_section_fields?
        errors[:existing_section_fields] << :non_empty_section_fields if record.section_fields.exists?
      end

      def validate_section_label
        duplicate_label_error(:label, section_data[:label], :duplicate_name_in_sections) if duplicate_section_label?(ticket_field, section_data)
      end

      def validate_section_choice_ids
        picklist_id_not_exists?(ticket_field, section_data[:choice_ids])
        picklist_id_taken?(ticket_field, record, section_data[:choice_ids])
      end
  end
end
