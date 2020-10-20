class TicketValidation < ApiValidation
  MANDATORY_FIELD_ARRAY = [:requester_id, :phone, :email, :twitter_id, 
    :facebook_id, :unique_external_id].freeze
  MANDATORY_FIELD_STRING_WITHOUT_UNIQUE_EXTERNAL_ID = (MANDATORY_FIELD_ARRAY - 
                              [:unique_external_id]).join(', ').freeze
  MANDATORY_FIELD_STRING = MANDATORY_FIELD_ARRAY.join(', ').freeze
  CHECK_PARAMS_SET_FIELDS = (MANDATORY_FIELD_ARRAY.map(&:to_s) +
                            %w(fr_due_by due_by subject description skip_close_notification
                               custom_fields company_id internal_group_id internal_agent_id skill_id related_ticket_ids parent_id tracker_id)
                            ).freeze

  attr_accessor :id, :cc_emails, :description, :due_by, :email_config_id, :fr_due_by, :group, :internal_group_id, :internal_agent_id, :priority, :email,
                :phone, :twitter_id, :facebook_id, :requester_id, :name, :agent, :source, :status, :subject, :ticket_type,
                :product, :tags, :custom_fields, :attachments, :request_params, :item, :statuses, :status_ids, :ticket_fields, :company_id, :scenario_id,
                :primary_id, :ticket_ids, :note_in_primary, :note_in_secondary, :convert_recepients_to_cc, :cloud_files, :skip_close_notification,
                :related_ticket_ids, :internal_group_id, :internal_agent_id, :parent_template_id, :child_template_ids, :template_text,
                :unique_external_id, :skill_id, :parent_id, :inline_attachment_ids, :tracker_id, :version, :enforce_mandatory, :fc_call_id

  alias_attribute :type, :ticket_type
  alias_attribute :product_id, :product
  alias_attribute :group_id, :group
  alias_attribute :responder_id, :agent

  # Default fields validation
  validates :subject, custom_absence: { message: :outbound_email_field_restriction }, if: :source_as_outbound_email?, on: :update
  validates :description, custom_absence: { message: :outbound_email_field_restriction }, if: :source_as_outbound_email?, on: :update
  validates :email_config_id, :subject, :email, required: { message: :field_validation_for_outbound }, if: :compose_email_or_proactive_rule_create?

  validates :subject, default_field: {
                        required_fields: proc { |x| x.required_default_fields },
                        field_validations: proc { |x| x.default_field_validations }
                      }, if: -> { create? || (update? && subject.present?) }

  validates :description, :ticket_type, :status, :priority, :product, :agent, :group, :internal_group_id, :internal_agent_id, default_field:
                              {
                                required_fields: proc { |x| x.required_default_fields },
                                field_validations: proc { |x| x.default_field_validations }
                              }, if: :create_or_update?

  validates :description, :ticket_type, :status, :subject, :priority, :product, :agent, :group, default_field:
                              {
                                required_fields: proc { |x| x.default_fields_to_validate },
                                field_validations: proc { |x| x.default_field_validations }
                              }, if: :is_bulk_update?

  validates :description, :ticket_type, :status, :priority, :group, default_field:
                              {
                                required_fields: proc { |x| x.required_default_fields },
                                field_validations: proc { |x| x.default_field_validations }
                              }, if: :compose_email_or_proactive_rule_create_update?

  validates :template_text, data_type: { rules: String, required: true }, on: :parse_template

  validates :source, custom_inclusion: { in: proc { |x| x.sources }, ignore_string: :allow_string_param, detect_type: true, allow_nil: true }, on: :create
  validates :source, custom_inclusion: { in: proc { |x| x.sources }, ignore_string: :allow_string_param, detect_type: true }, on: :compose_email
  validates :source, custom_inclusion: { in: proc { |x| x.update_sources }, ignore_string: :allow_string_param, detect_type: true }, unless: :private_api?, on: :update
  validates :requester_id, :email_config_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }

  validates :fc_call_id, data_type: { rules: Integer, allow_nil: true }, on: :create

  validates :company_id, custom_absence: {
    message: :require_feature_for_attribute,
    code: :inaccessible_field,
    message_options: {
      attribute: 'company_id',
      feature: :multiple_user_companies
    }
  }, unless: -> { Account.current.multiple_user_companies_enabled? }

  validates :related_ticket_ids, custom_absence: {
    message: :require_feature_for_attribute,
    code: :inaccessible_field,
    message_options: {
      attribute: 'related_ticket_ids',
      feature: :link_tickets
    }
  }, unless: -> { Account.current.link_tickets_enabled? }

  validates :tracker_id, custom_absence: {
    message: :require_feature_for_attribute,
    code: :inaccessible_field,
    message_options: {
      attribute: 'tracker_id',
      feature: :link_tickets
    }
  }, unless: -> { Account.current.link_tickets_enabled? }

  validates :parent_id, custom_absence: {
    message: :require_feature_for_attribute,
    code: :inaccessible_field,
    message_options: {
      attribute: 'parent_id',
      feature: :parent_child_infra
    }
  }, unless: -> { Account.current.parent_child_infra_enabled? }

  validates :parent_template_id, custom_absence: {
    message: :require_feature_for_attribute,
    code: :inaccessible_field,
    message_options: {
      attribute: 'parent_template_id',
      feature: :parent_child_tickets
    }
  }, unless: -> { parent_child_enabled? }

  validates :child_template_ids, custom_absence: {
    message: :require_feature_for_attribute,
    code: :inaccessible_field,
    message_options: {
      attribute: 'child_template_ids',
      feature: :parent_child_tickets
    }
  }, unless: -> { parent_child_enabled? }

  validates :company_id, custom_numericality: {
    only_integer: true,
    greater_than: 0,
    allow_nil: true,
    ignore_string: :allow_string_param
  }

  validates :internal_group_id, custom_absence: {
    message: :require_feature_for_attribute,
    code: :inaccessible_field,
    message_options: {
      attribute: 'internal_group_id',
      feature: :shared_ownership
    }
  }, unless: -> { Account.current.shared_ownership_enabled? }

  validates :internal_agent_id, custom_absence: {
    message: :require_feature_for_attribute,
    code: :inaccessible_field,
    message_options: {
      attribute: 'internal_agent_id',
      feature: :shared_ownership
    }
  }, unless: -> { Account.current.shared_ownership_enabled? }

  validates :skill_id, custom_absence: {
    message: :require_feature_for_attribute,
    code: :inaccessible_field,
    message_options: {
      attribute: 'skill_id',
      feature: :skill_based_round_robin
    }
  }, unless: -> { Account.current.skill_based_round_robin_enabled? }
  validates :skill_id, custom_absence: { allow_nil: true, message: :no_edit_ticket_skill_privilege }, if: -> { skill_id && errors[:skill_id].blank? && !User.current.privilege?(:edit_ticket_skill) }
  validates :skill_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }, if: -> { skill_id && errors[:skill_id].blank? && update_or_update_multiple? }

  validate :requester_detail_missing, if: -> { create_or_update? && requester_id_mandatory? }
  # validates :requester_id, required: { allow_nil: false, message: :fill_a_mandatory_field, message_options: { field_names: 'requester_id, phone, email, twitter_id, facebook_id' } }, if: :requester_id_mandatory? # No
  validates :name, required: { allow_nil: false, message: :phone_mandatory }, if: -> { create_or_update? && name_required? } # No
  validates :name, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }

  # Due by and First response due by validations
  # Both should not be present in params if status is closed or resolved
  validates :fr_due_by, custom_absence: { allow_nil: true, message: :cannot_set_due_by_fields }, if: :disallow_fr_due_by?
  validates :due_by, custom_absence: { allow_nil: true, message: :cannot_set_due_by_fields }, if: :disallow_due_by?
  # Either both should be present or both should be absent, cannot send one of them in params.
  validates :due_by, required: { message: :due_by_validation }, if: -> { fr_due_by && errors[:fr_due_by].blank? }
  validates :fr_due_by, required: { message: :fr_due_by_validation }, if: -> { due_by && errors[:due_by].blank? }
  # Both should be a valid datetime
  validates :due_by, :fr_due_by, date_time: { allow_nil: true }
  # Both should be greater than created_at
  validate :due_by_gt_created_at, if: -> { @due_by_set && due_by && errors[:due_by].blank? }
  validate :fr_due_gt_created_at, if: -> { @fr_due_by_set && fr_due_by && errors[:fr_due_by].blank? }
  # Due by should be greater than or equal to fr_due_by
  validate :due_by_gt_fr_due_by, if: -> { (@due_by_set || @fr_due_by_set) && due_by && fr_due_by && errors[:due_by].blank? && errors[:fr_due_by].blank? }

  # Attachment validations
  validates :attachments, required: true, if: -> { request_params.key? :attachments } # for attachments empty array scenario
  validates :attachments, data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: false } }
  validates :attachments, file_size:  {
    max: proc { |x| x.attachment_limit },
    base_size: proc { |x| ValidationHelper.attachment_size(x.item) }
  }

  # Parent child and linked ticket validations
  validates :related_ticket_ids, custom_absence: { message: :cannot_set_ticket_association_fields }, if: :disallow_associations?
  validates :parent_id, custom_absence: { message: :cannot_set_ticket_association_fields }, if: :disallow_associations?
  validates :related_ticket_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0 } }, custom_length: { maximum: TicketConstants::MAX_RELATED_TICKETS, message_options: { element_type: :values } }, if: -> { errors[:related_ticket_ids].blank? && errors[:parent_id].blank? }
  validates :parent_id, custom_numericality: {
    only_integer: true,
    greater_than: 0,
    ignore_string: :allow_string_param
  }, if: -> { errors[:related_ticket_ids].blank? && errors[:parent_id].blank? }

  validates :tracker_id, custom_numericality: {
    only_integer: true,
    greater_than: 0,
    allow_nil: true,
    ignore_string: :allow_string_param
  }

  # Email related validations
  validates :email, data_type: { rules: String, allow_nil: true }
  validates :email, custom_format: { with: proc { AccountConstants.email_validator }, accepted: :'valid email address', allow_nil: true }
  validates :email, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :cc_emails, data_type: { rules: Array }, array: { custom_format: { with: proc { AccountConstants.named_email_validator }, allow_nil: true, accepted: :'valid email address' } }

  validates :cc_emails, custom_length: { maximum: ApiTicketConstants::MAX_EMAIL_COUNT, message_options: { element_type: :values } }

  # Tags validations
  validates :tags, data_type: { rules: Array }, array: { data_type: { rules: String, allow_nil: true }, custom_length: { maximum: ApiConstants::TAG_MAX_LENGTH_STRING } }
  validates :tags, string_rejection: { excluded_chars: [','], allow_nil: true }

  # Validates enforce_mandatory param that should be either true or false
  validate  :validate_enforce_mandatory, if: -> { enforce_mandatory.present? }, only: [:create, :update]
  # Custom fields validations
  validates :custom_fields, data_type: { rules: Hash }
  # TODO: EMBER - error messages to be changed for validations that require values for fields on status change
  validates :custom_fields, custom_field: { custom_fields:
                              {
                                validatable_custom_fields: proc { |x| x.custom_fields_to_validate },
                                required_based_on_status: proc { |x| x.closure_status? },
                                required_attribute: :required,
                                ignore_string: :allow_string_param,
                                section_field_mapping: proc { |x| TicketsValidationHelper.section_field_parent_field_mapping }
                              } }, if: -> { errors[:custom_fields].blank? && (create_or_update? || is_bulk_update?) }
  validates :twitter_id, :phone, :name, data_type: { rules: String, allow_nil: true }
  validates :twitter_id, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :phone, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :scenario_id, required: true, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param }, if: -> { execute_scenario? }

  validates :primary_id, data_type: { rules: Integer }, required: true, on: :merge
  validates :ticket_ids, data_type: { rules: Array }, array: { data_type: { rules: Integer } }, required: true, on: :merge
  validates :convert_recepients_to_cc, custom_inclusion: { in: [true, false] }, on: :merge
  validates :note_in_primary, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.merge_note_fields_validation } }, required: true, on: :merge
  validates :note_in_secondary, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.merge_note_fields_validation } }, required: true, on: :merge

  validates :cloud_files, data_type: { rules: Array, allow_nil: false }
  validates :cloud_files, array: { data_type: { rules: Hash, allow_nil: false } }

  validate :validate_cloud_files, if: -> { cloud_files.present? && errors[:cloud_files].blank? }

  validates :skip_close_notification, custom_absence: { allow_nil: false, message: :cannot_set_skip_notification }, unless: -> { request_params.key?(:status) && closure_status? }
  validates :skip_close_notification, data_type: { rules: 'Boolean', ignore_string: :allow_string_param }, if: -> { errors[:skip_close_notification].blank? }

  validates :unique_external_id, custom_absence: { 
            message: :require_feature_for_attribute, 
            code: :inaccessible_field, 
            message_options: { 
              attribute: 'unique_external_id', 
              feature: :unique_contact_identifier 
            } 
          }, unless: :unique_external_identifier_enabled?

  validates :unique_external_id, data_type: { rules: String }, if: -> { unique_external_identifier_enabled? }
  validates :inline_attachment_ids, data_type: { rules: Array }

  def initialize(request_params, item, allow_string_param = false, additional_params = {})
    @request_params = request_params
    @status_ids = request_params[:statuses].map(&:status_id) if request_params.key?(:statuses)
    @enforce_mandatory = additional_params[:enforce_mandatory] || 'true'
    super(request_params, item, allow_string_param)
    @description = item.description_html if !request_params.key?(:description) && item
    @fr_due_by ||= item.try(:frDueBy).try(:iso8601) if item
    @due_by ||= item.try(:due_by).try(:iso8601) if item
    @product = item.product_id if !request_params.key?(:product_id) && item.try(:product_id)
    @item = item
    @additional_params = additional_params
    @version = @additional_params[:version]
    fill_custom_fields(request_params, item.custom_field_via_mapping) if item && item.custom_field_via_mapping.present?
  end

  def requester_detail_missing
    field = MANDATORY_FIELD_ARRAY.detect { |x| instance_variable_defined?("@#{x}_set") }
    field ? error_options[field] = { code: :invalid_value } : field = :requester_id
    errors[field] = :fill_a_mandatory_field
    field_names = unique_external_identifier_enabled? ? 
       MANDATORY_FIELD_STRING : MANDATORY_FIELD_STRING_WITHOUT_UNIQUE_EXTERNAL_ID
    (error_options[field] ||= {}).merge!(field_names: field_names)
  end

  def unique_external_identifier_enabled?
    Account.current.unique_contact_identifier_enabled?
  end

  def requester_id_mandatory? # requester_id is must if any one of email/twitter_id/fb_profile_id/phone is not given.
    MANDATORY_FIELD_ARRAY.all? { |x| safe_send(x).blank? && errors[x].blank? }
  end

  def name_required? # Name mandatory if phone number of a non existent contact is given. so that the contact will get on ticket callbacks.
    email.blank? && twitter_id.blank? && facebook_id.blank? && phone.present? && requester_id.blank?
  end

  def due_by_gt_created_at
    errors[:due_by] << :gt_created_and_now if due_by < (@item.try(:created_at) || Time.zone.now)
  end

  def fr_due_gt_created_at
    errors[:fr_due_by] << :gt_created_and_now if fr_due_by < (@item.try(:created_at) || Time.zone.now)
  end

  def due_by_gt_fr_due_by
    # Due By is parsed here as if both values are given as input string comparison would be done instead of Date Comparison.
    parsed_due_by = DateTime.parse(due_by)
    if fr_due_by > parsed_due_by
      att = @fr_due_by_set ? :fr_due_by : :due_by
      errors[att] << :lt_due_by
    end
  end

  def closure_status?
    status.respond_to?(:to_i) && [ApiTicketConstants::CLOSED, ApiTicketConstants::RESOLVED].include?(status.to_i)
  end

  # due_by and fr_due_by should not be allowed if status is closed or resolved for consistency with Web.
  def disallow_due_by?
    request_params[:due_by] && disallowed_status?
  end

  def disallow_fr_due_by?
    request_params[:fr_due_by] && disallowed_status?
  end

  def disallowed_status?
    errors[:status].blank? && statuses.detect { |x| x.status_id == status.to_i }.stop_sla_timer
  end

  def disallow_associations?
    request_params[:parent_id] && request_params[:related_ticket_ids]
  end

  def attributes_to_be_stripped
    ApiTicketConstants::ATTRIBUTES_TO_BE_STRIPPED
  end

  def required_default_fields
    tickets_api_relaxation_enabled? ? public_api_relaxed_required_default_fields : api_required_default_fields
  end

  def default_fields_to_validate
    required_default_fields.select { |x| validate_field?(x) }
  end

  def compose_email_or_proactive_rule_create_update?
    [:compose_email, :proactive_rule_create, :proactive_rule_update].include?(validation_context)
  end

  def compose_email_or_proactive_rule_create?
    [:compose_email, :proactive_rule_create].include?(validation_context)
  end

  def sources
    if Account.current.compose_email_enabled? && validation_context == :compose_email
      [Helpdesk::Source::OUTBOUND_EMAIL]
    elsif Account.current.compose_email_enabled?
      Account.current.helpdesk_sources.api_sources | [Helpdesk::Source::OUTBOUND_EMAIL]
    else
      Account.current.helpdesk_sources.api_sources
    end
  end

  def update_sources
    sources | [Helpdesk::Source::BOT]
  end

  def source_as_outbound_email?
    @outbound_email ||= (source == Helpdesk::Source::OUTBOUND_EMAIL) && Account.current.compose_email_enabled?
  end

  def default_field_validations
    {
      status: { custom_inclusion: { in: proc { |x| x.status_ids }, ignore_string: :allow_string_param, detect_type: true } },
      priority: { custom_inclusion: { in: ApiTicketConstants::PRIORITIES, ignore_string: :allow_string_param, detect_type: true } },
      ticket_type: { custom_inclusion: { in: proc { TicketsValidationHelper.ticket_type_values } } },
      group: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param } },
      agent: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param } },
      product: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param } },
      internal_group_id: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param } },
      internal_agent_id: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param } },
      subject: { data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } },
      description: { data_type: { rules: String } }
    }
  end

  def is_bulk_update?
    [:bulk_update].include?(validation_context)
  end

  def update_or_update_multiple?
    [:update, :bulk_update].include?(validation_context)
  end

  def execute_scenario?
    [:execute_scenario, :bulk_execute_scenario].include?(validation_context)
  end

  def merge_note_fields_validation
    {
      body: { data_type: { rules: String }, required: true },
      private: { custom_inclusion: { in: [true, false] }, required: true }
    }
  end

  def parent_child_enabled?
    Account.current.parent_child_tickets_enabled?
  end

  def validate_cloud_files
    cloud_file_hash_errors = []
    cloud_files.each_with_index do |cloud_file, index|
      cloud_file_validator = CloudFileValidation.new(cloud_file, nil)
      cloud_file_hash_errors << cloud_file_validator.errors.full_messages unless cloud_file_validator.valid?
    end
    errors[:cloud_files] << :"is invalid" if cloud_file_hash_errors.present?
  end

  def custom_fields_to_validate
    tkt_fields = TicketsValidationHelper.custom_non_dropdown_fields(self)
    create_or_update? ? tkt_fields : tkt_fields.select { |x| validate_field?(x) }
  end

  def validate_field?(x)
    if x.default?
      request_params.key?(ApiTicketConstants::FIELD_MAPPINGS[x.name.to_sym] || x.name.to_sym)
    else
      request_params[:custom_fields] ? request_params[:custom_fields].key?(x.name) : false
    end
  end

  def public_api_relaxed_required_default_fields
    case validation_context
    when :create
      mandatory_default_ticket_fields = Helpdesk::TicketField.where(name: ApiTicketConstants::TICKETS_API_RELAXATION_MANDATORY_FIELDS_FOR_CREATE)
      mandatory_default_ticket_fields + required_for_closure_default_fields
    when :update
      required_for_closure_default_fields
    else
      required_for_submit_or_closure_default_fields
    end
  end

  def api_required_default_fields
    case validation_context
    when :proactive_rule_update
      []
    else
      required_for_submit_or_closure_default_fields
    end
  end

  def required_for_submit_or_closure_default_fields
    ticket_fields.select { |x| x.default && (x.required || (x.required_for_closure && closure_status?)) }
  end

  def required_for_closure_default_fields
    ticket_fields.select { |x| x.default && (x.required_for_closure && closure_status?) }
  end

  private

    def tickets_api_relaxation_enabled?
      public_api? && User.current.tickets_api_relaxation?
    end

    def public_api?
      @version == 'v2'
    end

    def validate_enforce_mandatory
      unless %w[true false].include? @enforce_mandatory
        errors.add(:enforce_mandatory, ErrorConstants::ERROR_MESSAGES[:enforce_mandatory_value_error])
        return
      end
      @enforce_mandatory = @enforce_mandatory.to_bool
    end
end
