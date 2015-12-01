# A big thanks to http://blog.arkency.com/2014/05/mastering-rails-validations-objectify/ !!!!
class TicketDelegator < SimpleDelegator
  include ActiveModel::Validations

  attr_accessor :error_options, :ticket_fields
  validate :group_presence, if: -> { group_id && attr_changed?('group_id') }
  validate :responder_presence, if: -> { responder_id && attr_changed?('responder_id') }
  validates :email_config, :presence => true, if: -> { email_config_id && attr_changed?('email_config_id') }
  validate :product_presence, if: -> { product_id && attr_changed?('product_id', schema_less_ticket) }
  validate :user_blocked?, if: -> { requester_id && errors[:requester].blank? && attr_changed?('requester_id') }
  validates :custom_field,  custom_field: { custom_field:
                              {
                                validatable_custom_fields: proc { |x| Helpers::TicketsValidationHelper.custom_dropdown_fields(x) },
                                drop_down_choices: proc { Helpers::TicketsValidationHelper.custom_dropdown_field_choices },
                                nested_field_choices: proc { Helpers::TicketsValidationHelper.custom_nested_field_choices },
                                required_based_on_status: proc { |x| x.required_based_on_status? },
                                required_attribute: :required
                              }
                            }

  def initialize(record, options)
    @ticket_fields = options[:ticket_fields]
    super record
  end

  def attr_changed?(att, record = self)
    record.changed.include?(att)
  end

  def product_presence
    ticket_product_id = schema_less_ticket.product_id
    product = Account.current.products_from_cache.detect { |x| ticket_product_id == x.id }
    if product.nil?
      errors[:product_id] << :blank
    else
      schema_less_ticket.product = product
    end
  end

  def group_presence # this is a custom validate method so that group cache can be used.
    group = Account.current.groups_from_cache.detect { |x| group_id == x.id }
    if group.nil?
      errors[:group] << :blank
    else
      self.group = group
    end
  end

  def responder_presence #
    responder = Account.current.agents_from_cache.detect { |x| x.user_id == responder_id }.try(:user)
    if responder.nil?
      errors[:responder] << :blank
    else
      self.responder = responder
    end
  end

  def user_blocked?
    errors[:requester_id] << :user_blocked if requester && requester.blocked?
  end

  def required_based_on_status?
    [ApiTicketConstants::CLOSED, ApiTicketConstants::RESOLVED].include?(status.to_i)
  end
end
