class ScenarioDelegator < BaseDelegator
  attr_accessor :va_rule
  validate :scenario_presence, if: -> { @scenario_id.present? }
  validate :validate_closure, if: -> { @item.present? && errors[:scenario_id].blank? }
  validate :validate_type, if: -> { @item.present? && errors[:scenario_id].blank? }

  def initialize(record, options)
    @item = record
    options.each_pair do |key, val|
      instance_variable_set("@#{key.to_s}", val)
    end
    super(record, options)
  end

  def scenario_presence
    @va_rule = Account.current.scn_automations.find_by_id(@scenario_id)
    if @va_rule.nil?
      errors[:scenario_id] << :"is invalid"
    elsif !(@va_rule.visible_to_me? && @va_rule.check_user_privilege) # TODO: Privilege check to be revisited
      errors[:scenario_id] << :inaccessible_value
    end
  end

  def validate_closure
    @va_rule.trigger_actions_for_validation(@item, @user)
    if closure_status?
      delegator_hash = { ticket_fields: @ticket_fields, statuses: @statuses, request_params: [:status] }
      tkt_validation = TicketBulkUpdateDelegator.new(@item, delegator_hash)
      unless tkt_validation.valid?
        @errors = tkt_validation.errors
        (self.error_options ||= {}).merge!(tkt_validation.error_options)
      end
    end
  end

  def closure_status?
    [ApiTicketConstants::CLOSED, ApiTicketConstants::RESOLVED].include?(@item.status.to_i)
  end

  def validate_type
    errors[:id] << :fsm_ticket_scenario_failure if @item.service_task?
  end
end
