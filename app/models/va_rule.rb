class VaRule < ActiveRecord::Base

  self.primary_key = :id
  include Cache::Memcache::VARule

  TICKET_CREATED_EVENT = { :ticket_action => :created }
  CASCADE_DISPATCHR_DATA  = [
    [ :first, "dispatch.no_cascade",    0 ],
    [ :all,   "dispatch.cascade",        1 ] 
  ]

  serialize :filter_data
  serialize :action_data
  
  validates_presence_of :name, :rule_type
  validates_uniqueness_of :name, :scope => [:account_id, :rule_type] , :unless => :automation_rule?
  validate :has_events?, :has_conditions?, :has_actions?
  
  before_save :set_encrypted_password
  after_commit :clear_observer_rules_cache, :if => :observer_rule?
  after_commit :clear_api_webhook_rules_from_cache, :if => :api_webhook_rule?

  attr_writer :conditions, :actions, :events, :performer
  attr_accessor :triggered_event

  attr_accessible :name, :description, :match_type, :active, :filter_data, :action_data, :rule_type, :position

  belongs_to :account
  
  has_one :app_business_rule, :class_name=>'Integrations::AppBusinessRule', :dependent => :destroy
  has_one :installed_application, :class_name => 'Integrations::InstalledApplication', through: :app_business_rule
  scope :active, :conditions => { :active => true }
  scope :inactive, :conditions => { :active => false }
  scope :slack_destroy,:conditions => ["name in (?)",['slack_create', 'slack_update','slack_note']]

  scope :observer_biz_rules, :conditions => { 
    "va_rules.rule_type" => [VAConfig::INSTALLED_APP_BUSINESS_RULE], 
    "va_rules.active" => true }, :order => "va_rules.position"

  acts_as_list :scope => 'account_id = #{account_id} AND #{connection.quote_column_name("rule_type")} = #{rule_type}'

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
  
  def filter_data
    (observer_rule? || api_webhook_rule?) ? read_attribute(:filter_data).symbolize_keys : read_attribute(:filter_data)
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
    Va::Action.new(act_hash, self)
  end

  def check_events doer, evaluate_on, current_events
    return unless performer.matches? doer, evaluate_on
    is_a_match = event_matches? current_events, evaluate_on
    pass_through evaluate_on, nil, doer if is_a_match
  end

  def event_matches? current_events, evaluate_on
    Rails.logger.debug "INSIDE event_matches? WITH evaluate_on : #{evaluate_on.inspect}, va_rule #{self.inspect}"
    events.each do  |e|
      if e.event_matches?(current_events, evaluate_on)
        @triggered_event = {e.name => current_events[e.name]}
        return true
      end
    end
    return false
  end
  
  def pass_through(evaluate_on, actions=nil, doer=nil)
    Rails.logger.debug "INSIDE pass_through WITH evaluate_on : #{evaluate_on.inspect}, actions #{actions}"
    is_a_match = matches(evaluate_on, actions)
    trigger_actions(evaluate_on, doer) if is_a_match
    return evaluate_on if is_a_match
    return nil
  end
  
  def matches(evaluate_on, actions=nil)
    return true if conditions.empty?
    Rails.logger.debug "INSIDE matches WITH conditions : #{conditions.inspect}, actions #{actions}"
    s_match = match_type.to_sym   
    to_ret = false
    conditions.each do |c|
      current_evaluate_on = custom_eval(evaluate_on, c.evaluate_on_type)
      to_ret = !current_evaluate_on.nil? ? c.matches(current_evaluate_on, actions) : negation_operator?(c.operator)
      return true if to_ret && (s_match == :any)
      return false if !to_ret && (s_match == :all) #by Shan temp
    end
    
    return to_ret
  end

  def negation_operator?(operator)
    Va::Constants::NOT_OPERATORS.include?(operator)
  end

  def custom_eval(evaluate_on, key)
    case key
    when "ticket"
      evaluate_on
    when "requester"
      evaluate_on.requester
    when "company"
      evaluate_on.requester.company
    else
      evaluate_on # for backward compatibility
    end
  end
  
  def trigger_actions(evaluate_on, doer=nil)
    Va::ScenarioFlashMessage.initialize_activities if automation_rule?
    return false unless check_user_privilege
    @triggered_event ||= TICKET_CREATED_EVENT
    actions.each { |a| a.trigger(evaluate_on, doer, triggered_event) }
  end

  def fetch_actions_for_flash_notice(doer)
    Va::ScenarioFlashMessage.initialize_activities
    actions.each { |a| a.record_action_for_bulk(doer) }
  end
  
  def filter_query
    query_strings = []
    params = []
    c_operator = (match_type.to_sym == :any ) ? ' or ' : ' and '
    
    conditions.each do |c|
      c_query = c.filter_query
      unless c_query.blank?
        query_strings << c_query.shift
        params = params + c_query
      end
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

  def hide_password!
    return unless dispatchr_rule? || observer_rule? || api_webhook_rule?

    action_data.each do |action_data|
      action_data.symbolize_keys!
      if action_data[:name] == 'trigger_webhook' 
        action_data[:password] = '' and return
      end
    end
  end

  def set_encrypted_password
    return unless dispatchr_rule? || observer_rule? || api_webhook_rule?
    from_action_data, to_action_data = action_data_change
    webhook_action = nil

    
    to_action_data.each do |action_data|
      action_data.symbolize_keys!
      if action_data[:name] == 'trigger_webhook'
        return if action_data[:need_authentication].blank? || action_data[:api_key].present?
        if action_data[:password].blank? 
          webhook_action = action_data
        else
          action_data[:password] = encrypt(action_data[:password])
        end
        break
      end
    end

    unless (new_record? || webhook_action.nil?)
      from_action_data.each do |action_data|
        action_data.symbolize_keys!
        if action_data[:name] == 'trigger_webhook'
          webhook_action[:password] = action_data[:password]
          return true
        end
      end
    end
  end

  def observer_rule?
    rule_type == VAConfig::OBSERVER_RULE
  end

  def api_webhook_rule?
    rule_type == VAConfig::API_WEBHOOK_RULE
  end

  def supervisor_rule?
    rule_type == VAConfig::SUPERVISOR_RULE
  end

  def dispatchr_rule?
    rule_type == VAConfig::BUSINESS_RULE
  end

  def automation_rule?
    rule_type == VAConfig::SCENARIO_AUTOMATION
  end

  def self.cascade_dispatchr_option
    CASCADE_DISPATCHR_DATA.map { |i| [I18n.t(i[1]), i[2]] }
  end

  def check_user_privilege
    return true unless automation_rule?
    
    actions.each do |action|
      if Va::Action::ACTION_PRIVILEGE.key?(action.action_key.to_sym)
        return false unless
          User.current.privilege?(Va::Action::ACTION_PRIVILEGE[action.action_key.to_sym])
      end
    end
    true
  end


  private
    def has_events?
      return unless observer_rule? || api_webhook_rule?
      errors.add(:base,I18n.t("errors.events_empty")) if(filter_data[:events].blank?)
    end
    
    def has_conditions?
      return unless supervisor_rule?
      errors.add(:base,I18n.t("errors.conditions_empty")) if(filter_data.blank?)
    end
    
    def has_actions?
      errors.add(:base,I18n.t("errors.actions_empty")) if(action_data.blank?)
    end

    def filter_array
      (observer_rule? || api_webhook_rule?) ? filter_data[:conditions] : filter_data
    end

    def encrypt data
      public_key = OpenSSL::PKey::RSA.new(File.read("config/cert/public.pem"))
      Base64.encode64(public_key.public_encrypt(data))
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
