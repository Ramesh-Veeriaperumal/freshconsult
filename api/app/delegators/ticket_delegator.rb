# A big thanks to http://blog.arkency.com/2014/05/mastering-rails-validations-objectify/ !!!!
class TicketDelegator < SimpleDelegator
  include ActiveModel::Validations

  attr_accessor :error_options, :ticket_fields
  validate :group_presence, if: -> { group_id  }
  validate :responder_presence, if: -> { responder_id }
  validate :active_email_config, if: -> { email_config_id }
  validate :product_presence, if: -> { product_conditions }
  validate :responder_belongs_to_group?, if: -> { group_id && responder_id && errors[:responder].blank? && errors[:group].blank? }
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
    super record
  end

  def active_email_config
    errors.add(:email_config_id, "invalid_email_config") unless email_config.try(:active)
  end

  def product_conditions
    if validation_context == :create # validation_context is a ActiveModel::Validations method
      product_id && email_config_id.blank?
    else # update
      product_id
    end
  end

  def product_presence
    ticket_product_id = schema_less_ticket.product_id
    product = Account.current.products_from_cache.detect { |x| ticket_product_id == x.id }
    if product.nil?
      errors.add(:product, "can't be blank")
    else
      self.schema_less_ticket.product = product
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

  def responder_belongs_to_group?
    belongs_to_group = Account.current.agent_groups.exists?(group_id: group_id, user_id: responder_id)
    errors.add(:responder_id, 'not_part_of_group') unless belongs_to_group
  end
end
