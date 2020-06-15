class Admin::TicketFieldsDelegator < BaseDelegator
  include Admin::TicketFieldHelper

  attr_accessor(*PERMITTED_PARAMS)
  attr_accessor :request_params, :record, :tf, :column_name

  validate :validate_section_mappings, if: -> { section_mappings.present? && create_or_update? }
  validate :nested_level_db_validation, if: -> { dependent_fields.present? && record.nested_field? }, on: :update
  validate :validate_field_choices, if: -> { choices.present? && create_or_update? && (choices_required_for_type? || status_field? || source_field?) }
  validate :destroy_third_level_choices, if: -> { choices.blank? && dependent_fields.present? && choices_required_for_type? }, on: :update

  def initialize(record, request_params, _options)
    @request_params = request_params
    @tf = @record = record

    PERMITTED_PARAMS.each do |param|
      instance_variable_set("@#{param}", request_params[param])
    end
    super(record, request_params)
  end

  def validate_field_choices
    if record.safe_send(:status_field?)
      validate_status_choices(record, request_params[:choices])
    elsif record.safe_send(:source_field?)
      validate_source_choices(record, request_params[:choices])
    else
      validate_custom_choices(record, request_params[:choices])
    end
  end

  def destroy_third_level_choices
    return if errors.present?

    destroy_3rd_level = dependent_fields.find do |nested_field|
      nested_field[:level] == DEPENDENT_FIELD_LEVELS[1] && nested_field[:deleted].present?
    end.present?
    return if destroy_3rd_level.blank?

    choices = tf.picklist_values_with_sublevels
    skip_ticket_field_assignment(choices)
    destroy_choices_on_nested_level_deletion(tf, choices)
    tf.parent_level_choices = choices
  end

  private

    def current_account
      @account ||= Account.current
    end
end
