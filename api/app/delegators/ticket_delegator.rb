# A big thanks to http://blog.arkency.com/2014/05/mastering-rails-validations-objectify/ !!!!
class TicketDelegator < SimpleDelegator
  include ActiveModel::Validations

  attr_accessor :error_options, :ticket_fields
  validate :group_presence, if: -> { group_id  }
  validate :responder_presence, if: -> { responder_id }
  validate :active_email_config, if: -> { email_config_id }
  validate :product_presence, if: -> { get_product_id }
  validate :product_email_config_group_combination
  validate :user_blocked?, if: -> { errors[:requester].blank? && requester_id }
  validates :custom_field,  custom_field: { custom_field:
                              {
                                validatable_custom_fields: proc { |x| Helpers::TicketsValidationHelper.choices_validatable_custom_fields(x) },
                                drop_down_choices: proc { Helpers::TicketsValidationHelper.dropdown_choices_by_field_name },
                                nested_field_choices: proc { Helpers::TicketsValidationHelper.nested_fields_choices_by_name },
                                required_based_on_status: proc { |x| x.required_based_on_status? },
                                required_attribute: :required
                              }
                            }

  def initialize(record, options)
    @ticket_fields = options[:ticket_fields]
    @product_email_config_changed = options[:product_email_config_changed]
    super record
  end

  def active_email_config
    errors.add(:email_config_id, 'invalid_email_config') unless email_config.try(:active)
  end

  def product_presence
    product = Account.current.products_from_cache.detect { |x| get_product_id == x.id }
    if product.nil?
      errors.add(:product_id, "can't be blank")
    else
      schema_less_ticket.product = product
    end
  end

  def get_product_id
    schema_less_ticket.try(:product_id)
  end

  def set_product_id(product_id)
    schema_less_ticket.product_id = product_id if schema_less_ticket
  end

  # This will return true only if the product and email_config value is expected to change in an unexpected manner, i.e. different from the user's input.
  def config_conditions
    @product_email_config_changed && errors[:email_config_id].blank? && errors[:product_id].blank?
  end

  def product_email_config_group_combination
    flag = config_conditions
    if flag
      @old_product_id = get_product_id
      @old_email_config_id = email_config_id
      product_email_config_match
    end

    # This is not a separate validation to avoid extra call to assign_email_config_and_product_values
    responder_belongs_to_group(flag) if responder_id && errors[:responder].blank? && errors[:group].blank?

    # Reverting back to the input supplied by the user, as validations should not change state of object.
    if flag
      set_product_id(@old_product_id)
      self.email_config_id = @old_email_config_id
    end
  end

  def product_email_config_match
    assign_email_config_and_product_values
    errors.add(:product_id, 'product_mismatch') if get_product_id != @old_product_id
    errors.add(:email_config_id, 'email_config_mismatch') if email_config_id != @old_email_config_id
  end

  def assign_email_config_and_product_values
    validation_context == :create ? send(:assign_email_config_and_product) : send(:assign_email_config)
  end

  # Similar to the method present in ticket callbacks.
  def assign_email_config_and_product
    if email_config
      set_product_id(email_config.product_id)
    elsif get_product_id
      self.email_config = schema_less_ticket.product.primary_email_config
    end
  end

  # Similar to the method present in ticket callbacks.
  def assign_email_config
    return unless schema_less_ticket
    if schema_less_ticket.changed.include?('product_id')
      if product
        self.email_config = product.primary_email_config if email_config.nil? || (email_config.product.nil? || (email_config.product.id != product.id))
      else
        self.email_config = nil
      end
    end
  end

  def responder_belongs_to_group(flag)
    final_group_id = group_id || get_email_config(flag)
    valid = final_group_id.nil? || Account.current.agent_groups.exists?(group_id: final_group_id, user_id: responder_id)
    unless valid
      error_message = group_id ? 'not_part_of_group' : 'not_part_of_email_config_group'
      errors.add(:responder_id, error_message)
    end
  end

  def get_email_config(flag)
    if errors[:email_config_id].blank?
      assign_email_config_and_product_values unless flag
      group_id = email_config.try(:group_id)
    end
  end

  def group_presence # this is a custom validate method so that group cache can be used.
    group = Account.current.groups_from_cache.detect { |x| group_id == x.id }
    if group.nil?
      errors.add(:group, "can't be blank")
    else
      self.group = group
    end
  end

  def responder_presence #
    responder = Account.current.agents_from_cache.detect { |x| x.user_id == responder_id }.try(:user)
    if responder.nil?
      errors.add(:responder, "can't be blank")
    else
      self.responder = responder
    end
  end

  def user_blocked?
    errors.add(:requester_id, 'user_blocked') if requester && requester.blocked?
  end

  def required_based_on_status?
    [ApiTicketConstants::CLOSED, ApiTicketConstants::RESOLVED].include?(status.to_i)
  end
end
