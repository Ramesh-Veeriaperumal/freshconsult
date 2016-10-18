class ScenarioDelegator < BaseDelegator
  attr_accessor :va_rule
  validate :scenario_presence, if: -> { @scenario_id.present? }

  def initialize(record, options)
    @scenario_id = options[:scenario_id]
    super(record, options)
  end

  def scenario_presence
    @va_rule = Account.current.scn_automations.find_by_id(@scenario_id)
    if @va_rule.nil?
      errors[:scenario_id] << :"is invalid"
    elsif !(@va_rule.visible_to_me? && @va_rule.check_user_privilege)
      errors[:scenario_id] << :inaccessible_value
    end
  end
end
