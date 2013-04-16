class VARule < ActiveRecord::Base
  serialize :filter_data
  serialize :action_data
  
  validates_presence_of :name, :rule_type
  validates_uniqueness_of :name, :scope => [:account_id, :rule_type]
  validate :has_events?, :has_conditions?, :has_actions?
  
  attr_accessor :conditions, :actions, :events, :performer
  
  belongs_to :account
  
  has_one :app_business_rule, :class_name=>'Integrations::AppBusinessRule'

  named_scope :active, :conditions => { :active => true }
  named_scope :inactive, :conditions => { :active => false }

  named_scope :observer_biz_rules, :conditions => { 
    "va_rules.rule_type" => [VAConfig::INSTALLED_APP_BUSINESS_RULE], 
    "va_rules.active" => true }, :order => "va_rules.position"

  acts_as_list
  
  # scope_condition for acts_as_list
  def scope_condition
    "account_id = #{account_id} AND #{connection.quote_column_name("rule_type")} = #{rule_type}"
  end
  
  def after_find
    deserialize_all
  end

  def deserialize_all
    p "deserialize_all begins"
    p self
    p VAConfig::OBSERVER_RULE 
    p rule_type
    p "deserialize_all ends"

    if rule_type == VAConfig::OBSERVER_RULE
      filter_data.symbolize_keys!
      @performer = Va::Performer.new(filter_data[:performer].symbolize_keys)
      events_array = filter_data[:events]
      @filter_array = filter_data[:conditions]
      @events = events_array.blank? ? [] : 
                               events_array.collect { |e| Va::Event.new(e.symbolize_keys, account) } 
    end
    deserialize_them
  end
  
  def deserialize_them
    @filter_array ||= filter_data
    @conditions = @filter_array.blank? ? [] : 
                          @filter_array.collect { |f| Va::Condition.new(f.symbolize_keys, account) }
    @actions = action_data.map { |act| deserialize_action act } if action_data
  end
  
  def deserialize_action(act_hash)
    act_hash.symbolize_keys!
    Va::Action.new(act_hash)
  end

  def check_events doer, evaluate_on, current_events
    return unless performer.matches? doer, evaluate_on
    is_a_match = event_matches? current_events, evaluate_on
    pass_through evaluate_on, nil, doer if is_a_match
  end

  def event_matches? current_events, evaluate_on
    events.any? do  |e|
      e.event_matches? current_events, evaluate_on
    end
  end
  
  def pass_through(evaluate_on, actions=nil, doer=nil)
    RAILS_DEFAULT_LOGGER.debug "INSIDE pass_through WITH evaluate_on : #{evaluate_on.inspect}, actions #{actions}"
    is_a_match = matches(evaluate_on, actions)
    trigger_actions(evaluate_on, doer) if is_a_match
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
  
  def trigger_actions(evaluate_on, doer=nil)
    Va::Action.initialize_activities
    actions.each { |a| a.trigger(evaluate_on, doer) }
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
    def has_events?
      return unless(rule_type == VAConfig::OBSERVER_RULE)
      errors.add_to_base(I18n.t("errors.events_empty")) if(filter_data[:events].blank?)
    end
    
    def has_conditions?
      return unless(rule_type == VAConfig::SUPERVISOR_RULE)
      errors.add_to_base(I18n.t("errors.conditions_empty")) if(filter_data.blank?)
    end
    
    def has_actions?
      deserialize_all
      errors.add_to_base(I18n.t("errors.actions_empty")) if(action_data.blank?)
    end
  
end
