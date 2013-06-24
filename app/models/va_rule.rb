class VARule < ActiveRecord::Base

  include Cache::Memcache::VARule

  serialize :filter_data
  serialize :action_data
  
  validates_presence_of :name, :rule_type
  validates_uniqueness_of :name, :scope => [:account_id, :rule_type]
  validate :has_events?, :has_conditions?, :has_actions?
  
  after_commit :clear_observer_rules_cache, :if => :observer_rule?

  attr_writer :conditions, :actions, :events, :performer

  belongs_to :account
  
  has_one :app_business_rule, :class_name=>'Integrations::AppBusinessRule'

  named_scope :active, :conditions => { :active => true }
  named_scope :inactive, :conditions => { :active => false }

  named_scope :observer_biz_rules, :conditions => { 
    "va_rules.rule_type" => [VAConfig::INSTALLED_APP_BUSINESS_RULE], 
    "va_rules.active" => true }, :order => "va_rules.position"

  acts_as_list

  JOINS_HASH = {
    :helpdesk_schema_less_tickets => " inner join helpdesk_schema_less_tickets on 
          helpdesk_tickets.id = helpdesk_schema_less_tickets.ticket_id 
          and helpdesk_tickets.account_id = helpdesk_schema_less_tickets.account_id",
    :helpdesk_ticket_states => " inner join helpdesk_ticket_states on 
          helpdesk_tickets.id = helpdesk_ticket_states.ticket_id 
          and helpdesk_tickets.account_id = helpdesk_ticket_states.account_id",
    :customers => " inner join users on 
          helpdesk_tickets.requester_id = users.id  and users.account_id = 
          helpdesk_tickets.account_id left join customers on users.customer_id = 
          customers.id",
    :users => " inner join users on 
          helpdesk_tickets.requester_id = users.id  and users.account_id = 
          helpdesk_tickets.account_id ",
    :flexifields => " left join flexifields on helpdesk_tickets.id = 
          flexifields.flexifield_set_id  and helpdesk_tickets.account_id = 
          flexifields.account_id and flexifields.flexifield_set_type = 'Helpdesk::Ticket'"
  }
  
  # scope_condition for acts_as_list
  def scope_condition
    "account_id = #{account_id} AND #{connection.quote_column_name("rule_type")} = #{rule_type}"
  end
  
  def filter_data
    observer_rule? ? read_attribute(:filter_data).symbolize_keys : read_attribute(:filter_data)
  end

  def performer
    @performer ||= Va::Performer.new(filter_data[:performer].symbolize_keys)
  end

  def events
    @events ||= filter_data[:events].collect{ |e| Va::Event.new(e.symbolize_keys, account) }
  end

  def conditions
    @conditions ||= filter_array.collect{ |f| Va::Condition.new(f.symbolize_keys, account) }
  end

  def actions
    @actions ||= action_data.collect{ |act_hash| deserialize_action act_hash }
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
    return false unless check_user_privilege
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

  def negation_query
    query_strings = []
    params = []
    c_operator = VAConfig::NEGATE_CONDITION_OPERATOR
    negatable_conditions.each do |c|
      c_query = c.filter_query
      query_strings << c_query.shift
      params = params + c_query
    end
    query_strings.empty? ? [] : ([ query_strings.join(c_operator) ] + params)
  end
  
  def get_joins(conditions)
    all_joins = [""]
    JOINS_HASH.each do |table,join|
      next if table.eql?(:users) and conditions[0].include?(table.to_s) and conditions[0].include?("customers")
      all_joins[0].concat(join) if conditions[0].include?(table.to_s)
    end
    all_joins
  end

  private
    def has_events?
      return unless observer_rule?
      errors.add_to_base(I18n.t("errors.events_empty")) if(filter_data[:events].blank?)
    end
    
    def has_conditions?
      return unless(rule_type == VAConfig::SUPERVISOR_RULE)
      errors.add_to_base(I18n.t("errors.conditions_empty")) if(filter_data.blank?)
    end
    
    def has_actions?
      errors.add_to_base(I18n.t("errors.actions_empty")) if(action_data.blank?)
    end

    def filter_array
      observer_rule? ? filter_data[:conditions] : filter_data
    end

    def observer_rule?
      rule_type == VAConfig::OBSERVER_RULE
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

    def negatable_conditions
      conditions = []
      negatable_columns = VAConfig.negatable_columns(account)
      actions.map do |act|
        if negatable_columns.include? act.action_key
          conditions << (Va::Condition.new({ 
            :name => act.action_key, 
            :value => act.value, 
            :operator => VAConfig::NEGATE_OPERATOR
          }, account))
        elsif ( act.action_key.eql?("set_nested_fields") && negatable_columns.include?(act.act_hash[:category_name]) )
          conditions << (Va::Condition.new({ 
            :name => act.act_hash[:category_name], 
            :value => act.value, 
            :operator => VAConfig::NEGATE_OPERATOR
          }, account))
          act.act_hash[:nested_rules].each do |field|
            conditions << (Va::Condition.new({ 
              :name => field[:name], 
              :value => field[:value], 
              :operator => VAConfig::NEGATE_OPERATOR
            }, account))
          end
        end
      end
      conditions
    end

end
