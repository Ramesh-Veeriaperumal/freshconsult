class TicketUpdatePropertyValidation < ApiValidation
  include Admin::AdvancedTicketing::FieldServiceManagement::Util

  MANDATORY_FIELD_ARRAY = [:due_by, :agent, :group, :status].freeze
  MANDATORY_FIELD_STRING = MANDATORY_FIELD_ARRAY.join(', ').freeze
  CHECK_PARAMS_SET_FIELDS = %w(due_by skip_close_notification).freeze
  REQUEST_PARAM_MAPPING = { agent: :responder_id, group: :group_id }.freeze

  attr_accessor :due_by, :fr_due_by, :agent, :group, :product, :status, :priority, :item, :ticket_type, :request_params, :status_ids, :statuses, :ticket_fields,
                :custom_fields, :tags, :skip_close_notification, :description, :subject, :inline_attachment_ids

  alias_attribute :type, :ticket_type
  alias_attribute :product_id, :product
  alias_attribute :group_id, :group
  alias_attribute :responder_id, :agent

  validate :validate_property_update

  validates :description, :ticket_type, :status, :subject, :priority, :product, :agent, :group, default_field:
                    {
                      required_fields: proc { |x| x.required_default_fields },
                      field_validations: proc { |x| x.default_field_validations }
                    }, if: -> { errors.blank? }

  validates :due_by, custom_absence: { allow_nil: true, message: :cannot_set_due_by_fields }, if: :disallow_due_by?
  # Either both should be present or both should be absent
  validates :due_by, required: { message: :due_by_validation }, if: -> { errors.blank? && @due_by_set && fr_due_by && errors[:fr_due_by].blank? }
  validates :fr_due_by, required: { message: :fr_due_by_validation }, if: -> { errors.blank? && @due_by_set && due_by && errors[:due_by].blank? }

  validates :due_by, date_time: { allow_nil: true }, if: -> { errors.blank? && @due_by_set }

  validate :due_by_gt_created_at, if: -> { errors.blank? && @due_by_set && due_by && errors[:due_by].blank? }
  # Due by should be greater than or equal to fr_due_by
  validate :due_by_gt_fr_due_by, if: -> { errors.blank? && @due_by_set && due_by && fr_due_by && errors[:due_by].blank? && errors[:fr_due_by].blank? }

  # TODO: EMBER - error messages to be changed for validations that require values for fields on status change
  validates :custom_fields, custom_field: { custom_fields:
                              {
                                validatable_custom_fields: proc { |x| x.custom_fields_to_validate },
                                required_based_on_status: proc { |x| x.closure_status? },
                                ignore_string: :allow_string_param,
                                section_field_mapping: proc { |x| TicketsValidationHelper.section_field_parent_field_mapping }
                              } }

  # Tags validations
  validates :tags, data_type: { rules: Array }, array: { data_type: { rules: String, allow_nil: true }, custom_length: { maximum: ApiConstants::TAG_MAX_LENGTH_STRING } }
  validates :tags, string_rejection: { excluded_chars: [','], allow_nil: true }

  validates :skip_close_notification, custom_absence: { allow_nil: false, message: :cannot_set_skip_notification }, unless: -> { request_params.key?(:status) && closure_status? }
  validates :skip_close_notification, data_type: { rules: 'Boolean', ignore_string: :allow_string_param }, if: -> { errors[:skip_close_notification].blank? }
  validates :inline_attachment_ids, data_type: { rules: Array }

  def initialize(request_params, item, allow_string_param = false)
    @request_params = request_params
    @status_ids = request_params[:statuses].map(&:status_id) if request_params.key?(:statuses)
    super(request_params, item, allow_string_param)
    @fr_due_by ||= item.try(:frDueBy).try(:iso8601) if item
    @due_by ||= item.try(:due_by).try(:iso8601) if item
    @product = item.product_id if !request_params.key?(:product_id) && item.try(:product_id)
    @item = item
    fill_custom_fields(request_params, item.custom_field_via_mapping) if item && item.custom_field_via_mapping.present?
  end

  def due_by_gt_created_at
    errors[:due_by] << :gt_created_and_now if due_by < (@item.try(:created_at) || Time.zone.now)
  end

  def due_by_gt_fr_due_by
    # Due By is parsed here as if both values are given as input string comparison would be done instead of Date Comparison.
    parsed_due_by = DateTime.parse(due_by)
    errors[:due_by] << :lt_due_by if fr_due_by > parsed_due_by
  end

  def closure_status?
    status.respond_to?(:to_i) && [ApiTicketConstants::CLOSED, ApiTicketConstants::RESOLVED].include?(status.to_i)
  end

  # due_by should not be allowed if status is closed or resolved for consistency with Web.
  def disallow_due_by?
    errors.blank? && request_params[:due_by] && disallowed_status?
  end

  def disallowed_status?
    errors[:status].blank? && statuses.detect { |x| x.status_id == status.to_i }.stop_sla_timer
  end

  def required_default_fields
    default_fields_to_validate.select { |x| x.required || (closure_status? && x.required_for_closure) }
  end

  def default_fields_to_validate
    ticket_fields.select { |x| x.default && (validate_field?(x) || (x.required_for_closure && request_params.key?(:status) && closure_status?)) }
  end

  def custom_fields_to_validate
    TicketsValidationHelper.custom_non_dropdown_fields(self).select { |x| x.required_for_closure && request_params.key?(:status) && closure_status? }
  end

  def validate_field?(x)
    request_params.key?(ApiTicketConstants::FIELD_MAPPINGS[x.name.to_sym] || x.name.to_sym)
  end

  def default_field_validations
    {
      status: { custom_inclusion: { in: proc { |x| x.status_ids }, ignore_string: :allow_string_param, detect_type: true } },
      priority: { custom_inclusion: { in: ApiTicketConstants::PRIORITIES, ignore_string: :allow_string_param, detect_type: true } },
      ticket_type: { custom_inclusion: { in: proc { TicketsValidationHelper.ticket_type_values } } },
      group: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param } },
      agent: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param } },
      product: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param } },
      subject: { data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } },
      description: { data_type: { rules: String } }
    }.slice(*default_fields_to_validate.collect { |x| x.name.to_sym })
  end

  def validate_property_update
    params_size = request_params.except(:statuses, :ticket_fields).size
    if params_size < 1
      errors[:request] << :fill_a_mandatory_field
      error_options.merge!(request: { field_names: MANDATORY_FIELD_STRING })
    end
  end
end
