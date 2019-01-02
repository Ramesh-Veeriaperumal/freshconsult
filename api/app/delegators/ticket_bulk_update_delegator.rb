class TicketBulkUpdateDelegator < BaseDelegator
  attr_accessor :ticket_fields, :allow_string_param, :status_ids, :request_params, :product, :group, :agent

  validates :description, :ticket_type, :status, :subject, :priority, :product, :agent, :group, default_field:
                              {
                                required_fields: proc { |x| x.required_default_fields },
                                field_validations: proc { |x| x.default_field_validations }
                              }

  validate :group_presence, if: -> { group_id && errors[:group].blank? && status_set_to_closed? && !request_params.include?('group_id') }
  validate :product_presence, if: -> { product_id && errors[:product].blank? && status_set_to_closed? && !request_params.include?('product_id') }
  validate :responder_presence, if: -> { responder_id && errors[:responder].blank? && status_set_to_closed? && !request_params.include?('responder_id') }

  validates :custom_field_via_mapping, custom_field: { custom_field_via_mapping:
                              {
                                validatable_custom_fields: proc { |x| x.fields_to_validate(false) },
                                drop_down_choices: proc { TicketsValidationHelper.custom_dropdown_field_choices },
                                nested_field_choices: proc { TicketsValidationHelper.custom_nested_field_choices },
                                required_based_on_status: proc { |x| x.closure_status? },
                                required_attribute: :required,
                                section_field_mapping: proc { |x| TicketsValidationHelper.section_field_parent_field_mapping }
                              } }
  validate :validate_closure, if: -> { status_set_to_closed? }

  def initialize(record, options = {})
    @allow_string_param = false
    @ticket_fields = options[:ticket_fields]
    check_params_set(options[:custom_fields]) if options[:custom_fields].is_a?(Hash)
    @request_params = options[:request_params]
    @status_ids = options[:statuses].map(&:status_id) if options[:statuses]
    super(record, options)
    [:group, :product, :agent].each do |field|
      field_mapping = ApiTicketConstants::FIELD_MAPPINGS[field]
      instance_variable_set("@#{field}", (field == :product) ? schema_less_ticket.product_id : self.safe_send(field_mapping))
    end
  end

  def closure_status?
    [ApiTicketConstants::CLOSED, ApiTicketConstants::RESOLVED].include?(status.to_i)
  end

  def validate_closure
    errors[:status] << :unresolved_child if self.assoc_parent_ticket? && self.validate_assoc_parent_tkt_status
  end

  def default_field_validations
    {
      status: { custom_inclusion: { in: proc { |x| x.status_ids }, ignore_string: :allow_string_param, detect_type: true } },
      priority: { custom_inclusion: { in: ApiTicketConstants::PRIORITIES, ignore_string: :allow_string_param, detect_type: true } },
      ticket_type: { custom_inclusion: { in: proc { TicketsValidationHelper.ticket_type_values } } },
      group: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param } },
      responder: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param } },
      product: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param } },
      subject: { data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } },
      description: { data_type: { rules: String } }
    }.slice(*fields_to_validate(true).collect { |x| x.name.to_sym })
  end

  def required_default_fields
    fields_to_validate(true).select { |x| x.required || (closure_status? && x.required_for_closure) }
  end

  def fields_to_validate(default)
    ticket_fields.select { |x| x.default == default && (validate_field?(x) || (x.required_for_closure || (x.parent_id.present? && x.parent.required_for_closure)) && status_set_to_closed?) }
  end

  def group_presence # this is a custom validate method so that group cache can be used.
    return unless required_for_closure_field?('group')
    errors[:group] << :"can't be blank" unless Account.current.groups_from_cache.detect { |x| group_id == x.id }
  end

  def product_presence
    return unless required_for_closure_field?('product')
    ticket_product_id = schema_less_ticket.product_id
    errors[:product] << :"can't be blank" unless Account.current.products_from_cache.detect { |x| ticket_product_id == x.id }
  end

  def responder_presence
    return unless required_for_closure_field?('agent')
    errors[:responder] << :"can't be blank" unless Account.current.agents_details_from_cache.detect { |x| responder_id == x.id }
  end

  def required_for_closure_field?(field)
    ticket_fields.any? { |x| x.name == field && x.required_for_closure }
  end

  def status_set_to_closed?
    status && attr_changed?('status') && closure_status?
  end

  private

    def validate_field?(x)
      if x.default?
        request_params.include?((ApiTicketConstants::FIELD_MAPPINGS[x.name.to_sym] || x.name).to_s)
      else
        instance_variable_get("@#{x.name}_set")
      end
    end
end
