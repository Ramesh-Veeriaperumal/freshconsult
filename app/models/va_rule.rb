class VaRule < ActiveRecord::Base

  self.primary_key = :id
  include Cache::Memcache::VARule
  include Va::Constants
  include Redis::AutomationRuleRedis

  TICKET_CREATED_EVENT = { :ticket_action => :created }
  CASCADE_DISPATCHER_DATA  = [
    [ :first, "dispatch.no_cascade",    0 ],
    [ :all,   "dispatch.cascade",        1 ]
  ]


  xss_sanitize  :only => [:name, :description], :plain_sanitizer => [:name, :description]

  serialize :filter_data
  serialize :action_data
  serialize :condition_data

  concerned_with :presenter, :esv2_methods

  publishable on: [:create, :update, :destroy]

  validates_presence_of :name, :rule_type
  validates_uniqueness_of :name, :scope => [:account_id, :rule_type] , :unless => :automation_rule?
  validate :has_events?, :has_conditions?, :has_actions?, :has_safe_conditions?, :has_valid_action_data?
  validate :any_restricted_actions?
  validate :valid_position?, if: :position_changed?

  before_save :set_encrypted_password
  before_save :migrate_filter_data, :if => :conditions_changed?
  before_destroy :save_deleted_rule_info
  after_commit :clear_observer_rules_cache, :clear_observer_condition_field_names_cache, if: :ticket_observer_rule?
  after_commit :clear_service_task_observer_rules_cache, if: :service_task_observer_rule?
  after_commit :clear_api_webhook_rules_from_cache, :if => :api_webhook_rule?
  after_commit :clear_installed_app_business_rules_from_cache, :if => :installed_app_business_rule?
  after_commit :log_rule_change, if: :automated_rule?
  after_commit :perform_thank_you_redis_op, if: :ticket_observer_rule?
  after_commit :delete_rule_from_redis_set, on: :destroy, if: :ticket_observer_rule?
  after_update :reorder_rules, if: :position_changed?

  attr_writer :conditions, :actions, :events, :performer, :rule_operator,
              :rule_performer, :rule_events, :rule_conditions
  attr_accessor :triggered_event, :response_time, :affected_tickets_count, :frontend_positions,
                :current_evaluate_on_id

  attr_accessible :name, :description, :match_type, :active, :filter_data, :action_data, :rule_type, :position

  belongs_to_account

  has_one :app_business_rule, :class_name=>'Integrations::AppBusinessRule', :dependent => :destroy
  has_one :installed_application, :class_name => 'Integrations::InstalledApplication', through: :app_business_rule
  scope :active, :conditions => { :active => true }
  scope :inactive, :conditions => { :active => false }
  scope :slack_destroy,:conditions => ["name in (?)",['slack_create', 'slack_update','slack_note']]

  acts_as_list :scope => 'account_id = #{account_id} AND #{connection.quote_column_name("rule_type")} = #{rule_type}'

  alias_attribute :updated_by, :last_updated_by
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher

  JOINS_HASH = {
    :helpdesk_schema_less_tickets => " inner join helpdesk_schema_less_tickets on helpdesk_tickets.id = helpdesk_schema_less_tickets.ticket_id "\
          "and helpdesk_tickets.account_id = helpdesk_schema_less_tickets.account_id ",
    :helpdesk_ticket_states => " inner join helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id "\
          "and helpdesk_tickets.account_id = helpdesk_ticket_states.account_id ",
    :customers => " left join customers on helpdesk_tickets.owner_id = customers.id",
    :users => " inner join users on helpdesk_tickets.requester_id = users.id and users.account_id = helpdesk_tickets.account_id ",
    :flexifields => " left join flexifields on helpdesk_tickets.id = flexifields.flexifield_set_id  and helpdesk_tickets.account_id = "\
          "flexifields.account_id and flexifields.flexifield_set_type = 'Helpdesk::Ticket' "
  }

  IRREVERSIBLE_AUTOMATION_ACTIONS = %w[add_tag add_a_cc add_watcher send_email_to_group send_email_to_agent send_email_to_requester trigger_webhook slack_trigger office365_trigger].freeze

  def filter_data
    (self[:filter_data].present? && (observer_rule? || api_webhook_rule?)) ? read_attribute(:filter_data).symbolize_keys : read_attribute(:filter_data)
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

  def condition_data
    return self[:filter_data] if supervisor_rule?
    has_condition_data? && (observer_rule? || api_webhook_rule?) ?
          self[:condition_data].symbolize_keys : self[:condition_data]
  end

  def has_condition_data?
    supervisor_rule? ? self[:filter_data].present? : self[:condition_data].present?
  end

  def rule_operator
     @rule_operator ||= self[:match_type].try(:to_sym)  if supervisor_rule?
     @rule_operator ||= (observer_rule? ?
                          condition_data[:conditions].keys.first.to_sym :
                          condition_data.keys.first.to_sym) if has_condition_data?
  end

   def rule_performer
     @rule_performer ||= Va::Performer.new(condition_data[:performer].symbolize_keys) if has_condition_data?
   end

   def rule_events
     @rule_events ||= condition_data[:events].collect{ |e|
      Va::Event.new(e.symbolize_keys, account) } if has_condition_data?
   end

  def rule_conditions(with_dispatcher_key = nil, current_evaluate_on = false)
    return unless has_condition_data?
    conditions = []
    if observer_rule? || dispatchr_rule?
      modify_condition_sets(with_dispatcher_key, current_evaluate_on)
      conditions = condition_sets
    elsif supervisor_rule?
      conditions = condition_data
    end
    @rule_conditions ||= conditions
  end

  def modify_condition_sets(with_dispatcher_key = nil, current_evaluate_on = false)
    condition_sets.each do |set|
      if set.is_a?(Hash) && (set.key?(:any) || set.key?(:all))
        set.each_pair do |_, conditions|
          conditions.each do |condition|
            modify_condition(condition, with_dispatcher_key, current_evaluate_on)
          end
        end
      else
        modify_condition(set, with_dispatcher_key, current_evaluate_on)
      end
    end
  end

  def condition_sets
    condition_sets = observer_rule? ? condition_data[:conditions] : condition_data
    condition_sets.present? ? condition_sets.first[1] : {}
  end

  def modify_condition(condition, with_dispatcher_key, current_evaluate_on)
    field_type(condition)
    evaluate_on_id(condition) if current_evaluate_on
    fetch_dispatcher_column(condition, condition[:name]) if with_dispatcher_key
  end

  def field_type(condition)
    condition[:field_type] = fetch_field_type(condition)
  end

  def evaluate_on_id(condition)
    condition[:current_evaluate_on_id] = self.current_evaluate_on_id
  end

  def fetch_dispatcher_column(condition, name)
    condition[:name] = if Va::Condition::DISPATCHER_COLUMNS.key?(name)
                         Va::Condition::DISPATCHER_COLUMNS[name]
                       elsif !supervisor_rule? && Va::Condition::NEW_AUTOMATIONS_FIELD_CHANGE_MAPPING.key?(name.try(:to_sym))
                         Va::Condition::NEW_AUTOMATIONS_FIELD_CHANGE_MAPPING[name.try(:to_sym)]
                       else
                         name
                       end
  end

  def fetch_field_type(condition)
    case condition[:evaluate_on].try(:to_sym)
    when :requester
      contact_field = account.contact_form.custom_contact_fields.detect{ |cnf| cnf.name == condition[:name] }
      field_type = contact_field.present? ? contact_field.field_type.to_sym : :default
      # Rails.logger.info("Automation fetch_field_type: field_type: #{field_type}")
      field_type
    when :company
      company_field = account.company_form.custom_company_fields.detect{ |csf| csf.name == condition[:name] }
      field_type = company_field.present? ? company_field.field_type.to_sym : :default
      # Rails.logger.info("Automation fetch_field_type: field_type: #{field_type}")
      field_type
    else
      ff = account.flexifields_with_ticket_fields_from_cache.detect{ |ff|
          ff.flexifield_name == condition[:name] || ff.flexifield_alias == condition[:name] }
      ticket_field = ff.present? ? ff.ticket_field : nil
      field_type = ticket_field.present? && ticket_field.parent_id.nil? ? ticket_field.field_type.to_sym : :default
      # Rails.logger.info("Automation fetch_field_type, field_name: #{condition[:name]}, ticket_field present: #{ticket_field.present?}, ticket_field parent_id: #{ticket_field.try(:parent_id)}, field_type: #{field_type}")
      field_type
    end
  end

  def deserialize_action(act_hash)
    act_hash.symbolize_keys!
    Va::Action.new(act_hash, self)
  end

  def check_events doer, evaluate_on, current_events
    performer_matched = performer.matches? doer, evaluate_on
    Va::Logger::Automation.log("performer matched=#{performer_matched}")
    return unless performer_matched
    event_matched = event_matches? current_events, evaluate_on
    Va::Logger::Automation.log("event matched=#{event_matched}")
    pass_through evaluate_on, nil, doer if event_matched
  end

  def event_matches? current_events, evaluate_on
    events.each do  |e|
      if e.event_matches?(current_events, evaluate_on)
        @triggered_event = {e.name => current_events[e.name]}
        Va::Logger::Automation.log "matched event=#{@triggered_event.inspect}"
        return true
      end
    end
    return false
  end

  def pass_through(evaluate_on, actions=nil, doer=nil)
    is_a_match = false
    benchmark { is_a_match = matches(evaluate_on, actions) }
    Va::Logger::Automation.log("condition matched=#{is_a_match}")
    trigger_actions(evaluate_on, doer) if is_a_match
    is_a_match ? evaluate_on : nil
  end

  def matches(evaluate_on, actions=nil)
    return true if conditions.empty?
    Va::Logger::Automation.log("match_type=#{match_type}")
    s_match = match_type.to_sym
    to_ret = false
    conditions.each do |c|
      current_evaluate_on = custom_eval(evaluate_on, c.evaluate_on_type)
      to_ret = !current_evaluate_on.nil? ? c.matches(current_evaluate_on, actions) : negation_operator?(c.operator)
      if to_ret && (s_match == :any)
        Va::Logger::Automation.log("matched condition=#{c.handler.rule_hash.inspect}")
        return true
      end
      if !to_ret && (s_match == :all)
        Va::Logger::Automation.log("unmatched condition=#{c.handler.rule_hash.inspect}")
        return false
      end
    end
    return to_ret
  end

  def check_rule_events(doer, evaluate_on, current_events, original_ticket = nil)
    performer_matched = rule_performer.matches? doer, evaluate_on
    Va::Logger::Automation.log("rule performer matched=#{performer_matched}", true)
    return unless performer_matched
    event_matched = rule_event_matches? current_events, evaluate_on
    Va::Logger::Automation.log("rule event matched=#{event_matched}", true)
    check_rule_conditions evaluate_on, nil, doer, original_ticket if event_matched
  end

  def rule_event_matches?(current_events, evaluate_on)
    rule_events.each do  |e|
      if e.event_matches?(current_events, evaluate_on)
        @triggered_event = {e.name => current_events[e.name]}
        Va::Logger::Automation.log("matched rule event=#{@triggered_event.inspect}", true)
        return true
      end
    end
    false
  end

  def check_rule_conditions(evaluate_on, actions=nil, doer=nil, original_ticket=nil)
    is_a_match = false
    self.current_evaluate_on_id = evaluate_on.id
    ticket = original_ticket.presence || evaluate_on
    benchmark do
      is_a_match = RuleEngine::NestedCondition.new(ticket, rule_operator)
                                              .process_block(rule_conditions(true, true))
    end
    is_a_match = true if rule_conditions.blank? && observer_rule?
    Va::Logger::Automation.log("rule condition matched=#{is_a_match}", true)
    trigger_actions(evaluate_on, doer) if is_a_match
    is_a_match ? evaluate_on : nil
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
      evaluate_on.company
    else
      evaluate_on # for backward compatibility
    end
  end

  def trigger_actions(evaluate_on, doer=nil)
    Va::RuleActivityLogger.initialize_activities if automation_rule?
    return false unless check_user_privilege
    @triggered_event ||= TICKET_CREATED_EVENT
    add_rule_to_system_changes(evaluate_on) if evaluate_on.respond_to?(:system_changes)
    add_thank_you_note_to_system_changes(evaluate_on) if Thread.current[:thank_you_note].present?
    actions.each do |action|
      association_type = action.act_hash[:evaluate_on]
      action_key = action.act_hash[:name]
      ticket = PRIME_TICKETS.include?(association_type) ? associated_ticket(evaluate_on, association_type) : evaluate_on
      if ticket.present?
        if IRREVERSIBLE_AUTOMATION_ACTIONS.include?(action_key) && Account.current.ticket_observer_race_condition_fix_enabled?
          evaluate_on.enqueue_va_actions ||= []
          evaluate_on.enqueue_va_actions.append(action: action, ticket: ticket, doer: doer, triggered_event: triggered_event, only_reversible_actions: false, evaluate_on: evaluate_on)
        else
          action.trigger(ticket, doer, triggered_event, false, evaluate_on)
        end
      end
    end
    if @associated_ticket.present?
      @associated_ticket.perform_post_observer_actions = true
      @associated_ticket.prime_ticket_args = evaluate_on.prime_ticket_args
      @associated_ticket.prime_save
    end
    true
  end

  def associated_ticket(ticket, association_type)
    @associated_ticket ||= begin
      assoc_ticket = if association_type == 'parent_ticket'
        ticket.associated_prime_ticket('child')
      elsif association_type == 'tracker_ticket'
        ticket.associated_prime_ticket('related')
      end
      add_rule_to_system_changes(assoc_ticket)
      assoc_ticket
    end
  end

  def trigger_actions_for_validation(evaluate_on, doer=nil)
    actions.each { |a| a.trigger(evaluate_on, doer, nil, true) }
  end

  def add_rule_to_system_changes(evaluate_on)
    base_hash = {"#{self.id}" => {:rule => [self.rule_type, self.name.truncate(100)]}}
    if evaluate_on.system_changes.present?
      evaluate_on.system_changes.merge!(base_hash)
    else
      evaluate_on.system_changes = base_hash
    end
  end

  def add_thank_you_note_to_system_changes(evaluate_on)
    result_hash = Thread.current[:thank_you_note]
    evaluate_on.system_changes[self.id.to_s][:thank_you_note] = [result_hash[:result]] if result_hash[:rule_id] == self.id
    Thread.current[:thank_you_note] = nil
  end

  def fetch_actions_for_flash_notice(doer)
    Va::RuleActivityLogger.initialize_activities
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

    query_strings  = query_strings.map{ |query| "(#{query})" }
    query_strings.empty? ? [] : ([ query_strings.join(c_operator) ] + params)
  end

  def negation_query(negatable_columns =[])
    query_strings = []
    params = []
    c_operator = VAConfig::NEGATE_CONDITION_OPERATOR
    negatable_conditions(negatable_columns).each do |c|
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

  def conditions_changed?
    return if account.automation_revamp_enabled?
    self.changes.key?(:match_type) ||
      (self.changes.key?(:filter_data) &&
       self.changes[:filter_data][0] != self.changes[:filter_data][1])
  end

  def migrate_filter_data
    if dispatchr_rule?
      self.condition_data = { self.match_type.to_sym => self.filter_data }
    elsif observer_rule?
      self.condition_data = {
        performer: self.filter_data[:performer],
        events: self.filter_data[:events],
        conditions: { self.match_type.to_sym => self.filter_data[:conditions] }
      }
    end
  end

  def save_deleted_rule_info
    @deleted_model_info = central_publish_payload
  end

  def ticket_observer_rule?
    rule_type == VAConfig::OBSERVER_RULE
  end

  def observer_rule?
    ticket_observer_rule? || service_task_observer_rule?
  end

  def api_webhook_rule?
    rule_type == VAConfig::API_WEBHOOK_RULE
  end

  def installed_app_business_rule?
    rule_type == VAConfig::INSTALLED_APP_BUSINESS_RULE
  end

  def supervisor_rule?
    rule_type == VAConfig::SUPERVISOR_RULE
  end

  def ticket_dispatcher_rule?
    rule_type == VAConfig::BUSINESS_RULE
  end

  def dispatchr_rule?
    ticket_dispatcher_rule? || service_task_dispatcher_rule?
  end

  def automation_rule?
    rule_type == VAConfig::SCENARIO_AUTOMATION
  end

  def service_task_dispatcher_rule?
    rule_type == VAConfig::SERVICE_TASK_DISPATCHER_RULE
  end

  def service_task_observer_rule?
    rule_type == VAConfig::SERVICE_TASK_OBSERVER_RULE
  end

  def service_task_automation?
    service_task_dispatcher_rule? || service_task_observer_rule?
  end

  def automated_rule?
    observer_rule? || supervisor_rule? || dispatchr_rule?
  end


  def self.cascade_dispatcher_option
    CASCADE_DISPATCHER_DATA.map { |i| [I18n.t(i[1]), i[2]] }
  end

  # Used for sending webhook failure notifications
  def rule_type_desc
    if ticket_dispatcher_rule?
      I18n.t('admin.home.index.dispatcher')
    elsif ticket_observer_rule?
      I18n.t('admin.home.index.observer')
    elsif supervisor_rule?
      I18n.t('admin.home.index.supervisor')
    end
  end

  def rule_path
    if ticket_observer_rule?
      if account.automation_revamp_enabled?
        "#{Account.current.url_protocol}://#{Account.current.host}/a/admin/automations/ticket_updates/#{id}/edit"
      else
        Rails.application.routes.url_helpers.edit_admin_observer_rule_url(self.id,
                                                        host: Account.current.host,
                                                        protocol: Account.current.url_protocol)
      end
    elsif ticket_dispatcher_rule?
      if account.automation_revamp_enabled?
        "#{Account.current.url_protocol}://#{Account.current.host}/a/admin/automations/ticket_creation/#{id}/edit"
      else
        Rails.application.routes.url_helpers.edit_admin_va_rule_url(self.id,
                                                        host: Account.current.host,
                                                        protocol: Account.current.url_protocol)
      end
    elsif service_task_observer_rule? && account.automation_revamp_enabled?
      "#{Account.current.url_protocol}://#{Account.current.host}/a/field-service/admin/automations/service-task-updates/#{id}/edit"
    elsif service_task_dispatcher_rule? && account.automation_revamp_enabled?
      "#{Account.current.url_protocol}://#{Account.current.host}/a/field-service/admin/automations/service-task-creation/#{id}/edit"
    else
      I18n.t('not_available')
    end
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

  def filter_array
    (observer_rule? || api_webhook_rule?) ? filter_data[:conditions] : filter_data
  end

  def self.with_send_email_actions
    select {|va_rule| va_rule.contains_send_email_action?}
  end

  def any_restricted_actions?
    actions.any? {|action| action.restricted?}
  end

  def contains_send_email_action?
    actions.any? {|action| action.contains? 'send_email'}
  end

  def contains_add_watcher_action?
    actions.any? do |action|
      action.contains? 'add_watcher'
    end
  end

  def response_time
    @response_time ||= {}
  end

  def perform_thank_you_redis_op
    return unless account.detect_thank_you_note_enabled?

    thank_you_condition_exists = false
    rule_conditions.each do |condition_set|
      break if thank_you_condition_exists

      linear_conditions = condition_set[:all].presence || condition_set[:any].presence || condition_set
      thank_you_condition_exists = parse_linear_conditions(linear_conditions)
    end
    if thank_you_condition_exists
      add_element_to_automation_redis_set(automation_rules_with_thank_you_configured, id)
    else
      remove_element_from_automation_redis_set(automation_rules_with_thank_you_configured, id)
    end
  end

  def disable
    self.active = false
    self.save!
  end

  private

    def benchmark
      if observer_rule?
        response_time[:matches] = Benchmark.realtime { yield }
      else
        yield
      end
    end

    def has_events?
      return unless observer_rule? || api_webhook_rule?
      unless account.automation_revamp_enabled?
        errors.add(:base,I18n.t("errors.events_empty")) if filter_data[:events].blank?
      end
    end

    def has_conditions?
      return if !automated_rule? || account_id.zero?

      errors.add(:base,I18n.t("errors.conditions_empty")) if
        ((!account.automation_revamp_enabled? && filter_data.blank?) ||
          (account.automation_revamp_enabled? && condition_data.blank?))
    end

    def has_actions?
      errors.add(:base,I18n.t("errors.actions_empty")) if (action_data.blank?)
    end

    def encrypt data
      public_key = OpenSSL::PKey::RSA.new(File.read("config/cert/public.pem"))
      Base64.encode64(public_key.public_encrypt(data))
    end

    def negatable_conditions(negatable_columns = [])
      conditions = []
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

    def log_rule_change
      Va::Logger::Automation.set_thread_variables(account_id, nil, User.current.try(:id), id)
      Va::Logger::Automation.log("type=#{VAConfig::RULES_BY_ID[rule_type]}, name=#{self.name}", true)
      model_changes
    end

    def model_changes
      self.previous_changes.each {|k,v|
        next if k == 'updated_at' || v.first == v.last
        Va::Logger::Automation.log("attr=#{k}, old=#{v.first.inspect}, new=#{v.last.inspect}")
      }
    end

    # To make sure that condition operators are not being tampered.
    def has_safe_conditions?
      unless account.automation_revamp_enabled?
        return true if filter_array.nil?
        filter_array.each do |filter|
          filter.symbolize_keys!
          errors.add(:base,"Enter a valid condition") if filter[:operator].present? && va_operator_list[filter[:operator].to_sym].nil?
        end
      end
    end

    # To allow not more than 63K character in action_data
    def has_valid_action_data?
      return true if self.action_data.nil?
      if self.action_data.to_yaml.length >= MAX_ACTION_DATA_LIMIT
        errors.add(:base,I18n.t("admin.va_rules.webhook.action_data_limit_exceed"))
      end
    end

    def valid_position?
      errors.add(:base, I18n.t('admin.va_rules.position')) if position.nil? || !position.is_a?(Integer)
    end

    def position_changed?
      changes[:position].present?
    end

    def reorder_rules
      rule_association = VAConfig::ASSOCIATION_MAPPING[VAConfig::RULES_BY_ID[rule_type]]
      rules = account.safe_send("all_#{rule_association}".to_sym)
      old_rule_position = changes[:position][0]
      new_rule_position = changes[:position][1]
      reorder_from_higher_pos = old_rule_position > new_rule_position
      reorder_by = reorder_from_higher_pos ? '+' : '-'
      position_upper_index = reorder_from_higher_pos ? old_rule_position : new_rule_position
      position_lower_index = reorder_from_higher_pos ? new_rule_position : old_rule_position
      rules.where('position >= ? and position <= ? and id != ?',
                  position_lower_index, position_upper_index, id).update_all("position = position #{reorder_by} 1")
    end

    def parse_linear_conditions(linear_conditions)
      if linear_conditions.is_a?(Array)
        linear_conditions.select { |condition| thank_you_condition?(condition) }.present?
      else
        thank_you_condition?(linear_conditions)
      end
    end

    def thank_you_condition?(condition)
      condition[:evaluate_on] == :ticket && condition[:name] == 'freddy_suggestion' && condition[:value] == 'thank_you_note'
    end

    def delete_rule_from_redis_set
      return unless account.detect_thank_you_note_enabled?

      remove_element_from_automation_redis_set(automation_rules_with_thank_you_configured, id)
    end
end
