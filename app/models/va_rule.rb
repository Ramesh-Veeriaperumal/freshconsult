class VARule < ActiveRecord::Base
  serialize :filter_data
  serialize :action_data
  
  validates_presence_of :name, :rule_type
  validates_uniqueness_of :name, :scope => [:account_id, :rule_type]
  validate :has_conditions?, :has_actions?
  
  attr_accessor :conditions, :actions
  
  belongs_to :account
  
  has_one :app_business_rule, :class_name=>'Integrations::AppBusinessRule'

  named_scope :disabled, :conditions => { :active => false }

  named_scope :observer_biz_rules, :conditions => { "va_rules.rule_type" => [VAConfig::INSTALLED_APP_BUSINESS_RULE], "va_rules.active" => true }, :order => "va_rules.position"

  acts_as_list
  
  # scope_condition for acts_as_list
  def scope_condition
    "account_id = #{account_id} AND #{connection.quote_column_name("rule_type")} = #{rule_type}"
  end
  
  def after_find
    deserialize_them
  end
  
  def deserialize_them
    @conditions = []
    filter_data.each do |f|
      f.symbolize_keys!
      @conditions << (Va::Condition.new(f, account))
    end unless !filter_data
    
    @actions = action_data.map { |act| deserialize_action act } unless !action_data
  end
  
  def deserialize_action(act_hash)
    act_hash.symbolize_keys!
    Va::Action.new(act_hash)
  end
  
  def pass_through(evaluate_on, actions=nil)
    RAILS_DEFAULT_LOGGER.debug "INSIDE pass_through WITH evaluate_on : #{evaluate_on.inspect}, actions #{actions}"
    is_a_match = matches(evaluate_on, actions)
    trigger_actions(evaluate_on) if is_a_match    
    return evaluate_on if is_a_match
    return nil
  end
  
  def matches(evaluate_on, actions=nil)
    return true if conditions.empty?
    RAILS_DEFAULT_LOGGER.debug "INSIDE matches WITH conditions : #{conditions.inspect}, actions #{actions}"
    s_match = match_type.to_sym   
    to_ret = false
    conditions.each do |c|
      to_ret = c.matches(evaluate_on, actions)
            
      return true if to_ret && (s_match == :any)
      return false if !to_ret && (s_match == :all) #by Shan temp
    end
    
    return to_ret
  end
  
  def trigger_actions(evaluate_on)
    Va::Action.initialize_activities
    return false unless check_user_privilege
    actions.each { |a| a.trigger(evaluate_on) }
  end
  
  def filter_query
    query_strings = []
    params = []
    c_operator = (match_type.to_sym == :any ) ? ' or ' : ' and '
    
    conditions.each do |c|
      c_query = c.filter_query
      query_strings << c_query.shift
      params = params + c_query
    end
    
    query_strings.empty? ? [] : ([ query_strings.join(c_operator) ] + params)
  end
  
  private
    def has_conditions?
      return unless(rule_type == VAConfig::SUPERVISOR_RULE)
      errors.add_to_base(I18n.t("errors.conditions_empty")) if(filter_data.blank?)
    end
    
    def has_actions?
      deserialize_them
      errors.add_to_base(I18n.t("errors.actions_empty")) if(action_data.blank?)
    end

    def check_user_privilege
      return true unless rule_type == VAConfig::SCENARIO_AUTOMATION
      
      actions.each do |action|
        if Va::Action::ACTION_PRIVILEGE.key?(action.action_key.to_sym)
          return false unless
            User.current.privilege?(Va::Action::ACTION_PRIVILEGE[action.action_key.to_sym])
        end
      end
      true
    end

end
