class Admin::TicketFieldsDelegator < BaseDelegator
  include Admin::TicketFieldHelper

  attr_accessor(*PERMITTED_PARAMS)
  attr_accessor :request_params, :record, :tf, :column_name

  validate :validate_section_mappings, on: :create, if: -> { section_mappings.present? }
  validate :nested_level_db_validation, if: -> { dependent_fields.present? && record.nested_field? }, on: :update
  validate :validate_field_choices, if: -> { choices.present? && create_or_update? && (choices_required_for_type? || status_field?)}

  def initialize(record, request_params = {})
    @request_params = request_params
    @tf = @record = record

    PERMITTED_PARAMS.each do |param|
      instance_variable_set("@#{param}", request_params[param])
    end
    super(record, request_params)
  end

  def validate_field_choices
    if record.default?
      validate_status_choices_params(record, request_params[:choices])
    else
      validate_custom_choices(record, request_params[:choices])
    end
  end

  private

    def validate_section_mappings
      section_ids = section_mappings.map { |mapping| mapping[:section_id] }
      valid_sections = current_account.sections.where(id: section_ids)
      valid_section_ids = valid_sections.map(&:id)
      section_mappings.each do |mapping|
        invalid_section_mapping_error(:section_mapping, mapping[:section_id], :incorrect_section_mapping) unless mapping[:section_id].in?(valid_section_ids)
      end
      validate_parent_section_mappings(valid_sections)
    end

    def validate_parent_section_mappings(valid_sections)
      invalid_section_mapping_error(:parent_section_mapping) if valid_sections.map(&:parent_ticket_field_id).uniq.length > 1
    end

    def current_account
      @account ||= Account.current
    end
end
