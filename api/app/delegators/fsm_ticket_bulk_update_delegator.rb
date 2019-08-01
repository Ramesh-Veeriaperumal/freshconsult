# A big thanks to http://blog.arkency.com/2014/05/mastering-rails-validations-objectify/ !!!!
class FsmTicketBulkUpdateDelegator < TicketBulkUpdateDelegator
  attr_accessor :ticket_fields
  include Admin::AdvancedTicketing::FieldServiceManagement::Util

  def fields_to_validate(default)
    if default
      ticket_fields.select do |x|
        x.default &&
          x.name != 'product' &&
          (validate_field?(x) || (x.required_for_closure || (x.parent_id.present? && x.parent.required_for_closure)) &&
          status_set_to_closed?)
      end
    else
      fsm_fields_to_validate = fsm_custom_fields_to_validate
      fsm_fields_to_validate.select { |x| (validate_field?(x) || (x.required_for_closure || (x.parent_id.present? && x.parent.required_for_closure)) && status_set_to_closed?) }
    end
  end
end
