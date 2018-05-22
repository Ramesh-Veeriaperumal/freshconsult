# A big thanks to http://blog.arkency.com/2014/05/mastering-rails-validations-objectify/ !!!!
class TicketDelegator < BaseDelegator
  attr_accessor :ticket_fields
  validate :group_presence, if: -> { group_id && (attr_changed?('group_id') || (property_update? && required_for_closure_field?('group') && status_set_to_closed?)) }
  validate :responder_presence, if: -> { responder_id && (attr_changed?('responder_id') || (property_update? && required_for_closure_field?('agent') && status_set_to_closed?)) }
  validate :email_config_presence,  if: -> { !property_update? && email_config_id && outbound_email? }
  validates :email_config, presence: true, if: -> { errors[:email_config_id].blank? && email_config_id && attr_changed?('email_config_id') }
  validate :product_presence, if: -> { product_id && (attr_changed?('product_id', schema_less_ticket) || (property_update? && required_for_closure_field?('product') && status_set_to_closed?)) }
  validate :validate_user, if: -> { requester_id && errors[:requester].blank? && attr_changed?('requester_id') }
  validates :custom_field_via_mapping,  custom_field: { custom_field_via_mapping:
                              {
                                validatable_custom_fields: proc { |x| TicketsValidationHelper.custom_dropdown_fields(x) },
                                drop_down_choices: proc { TicketsValidationHelper.custom_dropdown_field_choices },
                                nested_field_choices: proc { TicketsValidationHelper.custom_nested_field_choices },
                                required_based_on_status: proc { |x| x.closure_status? },
                                required_attribute: :required,
                                section_field_mapping: proc { |x| TicketsValidationHelper.section_field_parent_field_mapping }
                              } }, unless: -> { property_update? || bulk_update? }
  validates :custom_field_via_mapping,  custom_field: { custom_field_via_mapping:
                              {
                                validatable_custom_fields: proc { |x| x.custom_fields_to_validate },
                                drop_down_choices: proc { TicketsValidationHelper.custom_dropdown_field_choices },
                                nested_field_choices: proc { TicketsValidationHelper.custom_nested_field_choices },
                                required_based_on_status: proc { |x| x.closure_status? },
                                required_attribute: :required,
                                section_field_mapping: proc { |x| TicketsValidationHelper.section_field_parent_field_mapping }
                              } }, if: :bulk_update?

  validates :custom_field_via_mapping,  custom_field: { custom_field_via_mapping:
                              {
                                validatable_custom_fields: proc { |x| x.custom_fields_to_validate },
                                drop_down_choices: proc { TicketsValidationHelper.custom_dropdown_field_choices },
                                nested_field_choices: proc { TicketsValidationHelper.custom_nested_field_choices },
                                required_based_on_status: proc { |x| x.closure_status? },
                                section_field_mapping: proc { |x| TicketsValidationHelper.section_field_parent_field_mapping }
                              } }, if: :property_update?

  validate :facebook_id_exists?, if: -> { !property_update? && facebook_id }

  validate :validate_application_id, if: -> { cloud_files.present? }

  validate :validate_closure, if: -> { status_set_to_closed? && !bulk_update? }

  validate :company_presence, if: -> { @company_id }

  validate :validate_internal_agent_group_mapping, if: -> { internal_agent_id && attr_changed?('internal_agent_id') && Account.current.shared_ownership_enabled? }
  validate :validate_status_group_mapping, if: -> { internal_group_id && attr_changed?('internal_group_id') && Account.current.shared_ownership_enabled? }

  validate :parent_template_id_permissible?, if: -> { @parent_template_id }

  validate :child_template_ids_permissible?, if: -> { @child_template_ids }
  validate :validate_parent_ticket, if: -> { child_ticket? && @parent.present? }

  validate :parent_template_id_permissible?, if: -> { @parent_template_id }
  validate :child_template_ids_permissible?, if: -> { @child_template_ids }

  validate :validate_skill, if: -> { sl_skill_id && attr_changed?('sl_skill_id') }
                                  
  validate :create_tag_permission, if: -> { @tags }

  validate :validate_inline_attachment_ids, if: -> { @inline_attachment_ids }

  def initialize(record, options)
    @ticket_fields = options[:ticket_fields]
    check_params_set(options[:custom_fields]) if options[:custom_fields].is_a?(Hash)
    if options[:parent_attachment_params].present?
      @parent = options[:parent_attachment_params][:parent_ticket]
      @parent_attachments = options[:parent_attachment_params][:parent_attachments]
      @parent_template_attachments = options[:parent_attachment_params][:parent_template_attachments]
    end
    options[:attachment_ids] = skip_existing_attachments(options) if options[:attachment_ids]
    @inline_attachment_ids = options[:inline_attachment_ids]
    if options[:parent_child_params].present?
      @parent_template_id = options[:parent_child_params][:parent_template_id]
      @child_template_ids = options[:parent_child_params][:child_template_ids]
    end
    @company_id = options[:company_id]
    @tags = options[:tags]
    super(record, options)
    @ticket = record
  end

  def product_presence
    ticket_product_id = schema_less_ticket.product_id
    product = Account.current.products_from_cache.detect { |x| ticket_product_id == x.id }
    if product.nil?
      errors[:product_id] << :"can't be blank"
    else
      schema_less_ticket.product = product
    end
  end

  def group_presence # this is a custom validate method so that group cache can be used.
    group = Account.current.groups_from_cache.detect { |x| group_id == x.id }
    if group.nil?
      errors[:group] << :"can't be blank"
    else
      self.group = group
    end
  end

  def responder_presence #
    responder = Account.current.agents_details_from_cache.detect { |x| x.id == responder_id }
    if responder.nil?
      errors[:responder] << :"can't be blank"
    else
      self.responder = responder
    end
  end

  def email_config_presence
    email_config = Account.current.email_configs.where(id: email_config_id).first
    if email_config.nil?
      errors[:email_config_id] << :"can't be blank"
    elsif !User.current.can_view_all_tickets? && Account.current.restricted_compose_enabled? && (User.current.group_ticket_permission || User.current.assigned_ticket_permission)
      accessible_email_config = email_config.group_id.nil? || User.current.agent_groups.exists?(group_id: email_config.group_id)
      errors[:email_config_id] << :inaccessible_value unless accessible_email_config
    end
  end

  def company_presence
    company = Account.current.companies.find_by_id(@company_id)
    if company.nil?
      errors[:company_id] << :invalid_company_id
      @error_options[:company_id] = { company_id: @company_id }
    end
  end

  def validate_user
    if requester
      if requester.blocked?
        errors[:requester_id] << :user_blocked
      elsif requester.email.present?
        @ticket.email = requester.email
      end
    end
  end

  def parent_template_id_permissible?
    @parent_template = Account.current.prime_templates.find_by_id(@parent_template_id)
    if @parent_template.blank? || !@parent_template.visible_to_me?
      errors[:parent_template_id] << :"is invalid"
    end
  end

  def child_template_ids_permissible?
    if @parent_template.present? && @child_template_ids.present?
      valid_child_template_ids = @parent_template.child_templates.pluck(:id)
      invalid_child_template_ids = @child_template_ids.to_a - valid_child_template_ids
      if invalid_child_template_ids.length > 0
        errors[:child_template_ids] << :child_template_list
        (self.error_options ||= {}).merge!({ child_template_ids: { invalid_ids: "#{invalid_child_template_ids.join(', ')}" } })
      end
    end
  end

  def closure_status?
    [ApiTicketConstants::CLOSED, ApiTicketConstants::RESOLVED].include?(status.to_i)
  end

  def facebook_id_exists?
    unless Account.current.all_users.exists?(['fb_profile_id = ?', facebook_id.to_s])
      errors[:facebook_id] << :invalid_facebook_id
    end
  end

  def validate_application_id
    application_ids = cloud_files.map(&:application_id)
    applications = Integrations::Application.where('id IN (?)', application_ids)
    invalid_ids = application_ids - applications.map(&:id)
    if invalid_ids.any?
      errors[:application_id] << :invalid_list
      (self.error_options ||= {}).merge!(application_id: { list: invalid_ids.join(', ').to_s })
    end
  end

  def validate_closure
    errors[:status] << :unresolved_child if self.assoc_parent_ticket? && self.validate_assoc_parent_tkt_status
  end

  def custom_fields_to_validate
    custom_drodpowns = TicketsValidationHelper.custom_dropdown_fields(self)
    if bulk_update?
      custom_drodpowns.select { |x| instance_variable_get("@#{x.name}_set") }
    else
      custom_drodpowns.select { |x| x.required_for_closure && status_set_to_closed? }
    end
  end

  def required_for_closure_field?(_x)
    ticket_fields.select { |x| x.name == x && x.required_for_closure }
  end

  def status_set_to_closed?
    status && attr_changed?('status') && closure_status?
  end

  def validate_internal_agent_group_mapping
    errors[:internal_agent] << :wrong_internal_agent unless @ticket.valid_internal_agent?
  end

  def validate_status_group_mapping
    errors[:internal_group] << :wrong_internal_group unless @ticket.valid_internal_group?
  end

  def validate_parent_ticket
    if @parent.cannot_add_child? || !@parent.can_be_associated?
      errors[:parent_id] << :invalid_parent
    elsif @parent.assoc_parent_ticket? && @parent.child_tkts_count >= TicketConstants::CHILD_TICKETS_PER_ASSOC_PARENT
      errors[:parent_id] << :exceeds_limit
      @error_options[:limit] = TicketConstants::CHILD_TICKETS_PER_ASSOC_PARENT
    end
  end

  def validate_skill
    skill = Account.current.skills_from_cache.detect { |x| sl_skill_id == x.id }
    if skill.nil?
      errors[:skill_id] << :invalid_skill_id
      @error_options[:skill_id] = { skill_id: skill_id }
    end
  end
                                  
  def create_tag_permission 
    new_tag = @tags.find{ |tag| tag.new_record? }
    if new_tag && !User.current.privilege?(:create_tags)
      errors[:tags] << "cannot_create_new_tag"
      @error_options[:tags] = { tags: new_tag.name }
    end
  end                                

  def validate_inline_attachment_ids
    valid_ids = Account.current.attachments.where(id: @inline_attachment_ids, attachable_type: 'Tickets Image Upload').pluck(:id)
    valid_ids = valid_ids + @ticket.inline_attachment_ids unless @ticket.new_record? # Skip existing inline attachments while validating
    invalid_ids = @inline_attachment_ids - valid_ids
    if invalid_ids.present?
      errors[:inline_attachment_ids] << :invalid_inline_attachments_list
      (self.error_options ||= {}).merge!({ inline_attachment_ids: { invalid_ids: "#{invalid_ids.join(', ')}" } })
    end
  end

  private

    def property_update?
      [:update_properties].include?(validation_context)
    end

    def bulk_update?
      [:bulk_update].include?(validation_context)
    end

    # skip shared attachments
    def skip_existing_attachments(options)
      attachment_ids_list = (options[:attachment_ids] - (options[:shared_attachments] || []).map(&:id) - (@parent_attachments.present? ? @parent_attachments : []).map(&:id))
      attachment_ids_list = attachment_ids_list - @parent_template_attachments.map(&:id) if @parent_template_attachments.present?
      attachment_ids_list
    end
end
