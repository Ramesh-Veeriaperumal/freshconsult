# A big thanks to http://blog.arkency.com/2014/05/mastering-rails-validations-objectify/ !!!!
class TicketDelegator < BaseDelegator
  attr_accessor :ticket_fields
  validate :group_presence, if: -> { group_id && attr_changed?('group_id') }
  validate :responder_presence, if: -> { responder_id && attr_changed?('responder_id') }
  validate :email_config_presence,  if: -> {  !property_update? && email_config_id && outbound_email? }
  validates :email_config, presence: true, if: -> { errors[:email_config_id].blank? && email_config_id && attr_changed?('email_config_id') }
  validate :product_presence, if: -> { product_id && attr_changed?('product_id', schema_less_ticket) }
  validate :user_blocked?, if: -> { requester_id && errors[:requester].blank? && attr_changed?('requester_id') }
  validates :custom_field_via_mapping,  custom_field: { custom_field_via_mapping:
                              {
                                validatable_custom_fields: proc { |x| TicketsValidationHelper.custom_dropdown_fields(x) },
                                drop_down_choices: proc { TicketsValidationHelper.custom_dropdown_field_choices },
                                nested_field_choices: proc { TicketsValidationHelper.custom_nested_field_choices },
                                required_based_on_status: proc { |x| x.closure_status? },
                                required_attribute: :required,
                                section_field_mapping: proc { |x| TicketsValidationHelper.section_field_parent_field_mapping }
                              }
                            }, unless: -> { property_update? || bulk_update? }
  validates :custom_field_via_mapping,  custom_field: { custom_field_via_mapping:
                              {
                                validatable_custom_fields: proc { |x| TicketsValidationHelper.custom_dropdown_fields(x) },
                                drop_down_choices: proc { TicketsValidationHelper.custom_dropdown_field_choices },
                                nested_field_choices: proc { TicketsValidationHelper.custom_nested_field_choices },
                                required_based_on_status: proc { |x| x.closure_status? }
                              }
                            }, if: :property_update?
  validate :facebook_id_exists?, if: -> { !property_update? && facebook_id }

  validate :validate_application_id, if: -> { cloud_files.present? }

  validate :validate_closure, if: -> { status && attr_changed?('status') && !bulk_update? }

  def initialize(record, options)
    @ticket_fields = options[:ticket_fields]
    check_params_set(options[:custom_fields]) if options[:custom_fields].is_a?(Hash)
    options[:attachment_ids] = skip_existing_attachments(options) if options[:attachment_ids]
    super(record, options)
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
    responder = Account.current.agents_from_cache.detect { |x| x.user_id == responder_id }.try(:user)
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

  def user_blocked?
    errors[:requester_id] << :user_blocked if requester && requester.blocked?
  end

  def closure_status?
    [ApiTicketConstants::CLOSED, ApiTicketConstants::RESOLVED].include?(status.to_i)
  end

  def facebook_id_exists?
    unless Account.current.all_users.exists?(['fb_profile_id = ?', "#{facebook_id}"])
      errors[:facebook_id] << :invalid_facebook_id
    end
  end

  def validate_application_id
    application_ids = cloud_files.map(&:application_id)
    applications = Integrations::Application.where('id IN (?)', application_ids)
    invalid_ids = application_ids - applications.map(&:id)
    if invalid_ids.any?
      errors[:application_id] << :invalid_list
      (self.error_options ||= {}).merge!({ application_id: { list: "#{invalid_ids.join(', ')}" } })
    end
  end

  def validate_closure
    return unless closure_status?
    errors[:status] << :unresolved_child if self.assoc_parent_ticket? && self.validate_assoc_parent_tkt_status
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
      options[:attachment_ids] - (options[:shared_attachments] || []).map(&:id)
    end
end
