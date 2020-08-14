class Agent < ActiveRecord::Base
  self.primary_key = :id
  self.table_name = :agents

  include Publish
  include Cache::Memcache::Agent
  include Agents::Preferences
  include Social::Ext::AgentMethods
  include Chat::Constants
  include Redis::RoundRobinRedis
  include RoundRobinCapping::Methods
  include Redis::RedisKeys
  include Redis::OthersRedis
  include DataVersioning::Model
  include RabbitMq::Publisher
  include Admin::ShiftHelper

  VERSION_MEMBER_KEY = 'AGENTS_GROUPS_LIST'.freeze

  concerned_with :associations, :constants, :presenter
  serialize :additional_settings, Hash

  publishable on: [:create, :update, :destroy]

  before_destroy :remove_escalation, :save_deleted_agent_info

  accepts_nested_attributes_for :user
  accepts_nested_attributes_for :agent_groups, :allow_destroy => true
  before_update :update_active_since, :create_model_changes
  before_update :destroy_contribution_group_on_permission_change, if: :ticket_permission_changed?

  before_create :mark_unavailable
  before_save :update_agent_group_change
  after_commit :enqueue_round_robin_process, on: :update
  after_commit :sync_skill_based_queues, on: :update
  after_commit :sync_agent_availability_to_ocr, on: :update, if: -> { allow_ocr_sync? && !skip_ocr_agent_sync }

  after_commit :nullify_tickets, :agent_destroy_cleanup, on: :destroy
  
  after_commit  ->(obj) { obj.update_agent_to_livechat } , on: :create
  after_commit  ->(obj) { obj.update_agent_to_livechat } , on: :update

  before_save :set_default_type_if_needed, on: [:create, :update]

  before_create :check_if_agent_limit_reached?, if: :full_time_support_agent?

  after_rollback :decrement_agent_count_in_redis, if: :full_time_support_agent?
  after_destroy :decrement_agent_count_in_redis, if: :full_time_support_agent?

  validates_presence_of :user_id
  validate :validate_signature
  validate :check_agent_type_changed, on: :update
  validate :validate_field_agent_groups, if: :check_field_agent_groups?
  validate :check_ticket_permission, :validate_field_agent_state, if: -> { account.field_service_management_enabled? }
  # validate :only_primary_email, :on => [:create, :update] moved to user.rb

  attr_accessible :signature_html, :user_id, :ticket_permission, :occasional, :available, :shortcuts_enabled, :field_service, :undo_send, :falcon_ui, :shortcuts_mapping,
                  :scoreboard_level_id, :user_attributes, :group_ids, :freshchat_token, :agent_type, :search_settings, :focus_mode, :show_onBoarding, :notification_timestamp, :show_loyalty_upgrade
  attr_accessor :agent_role_ids, :freshcaller_enabled, :user_changes, :group_changes,
                :ocr_update, :misc_changes, :out_of_office_days, :old_agent_availability,
                :return_old_agent_availability, :freshchat_enabled, :skip_ocr_agent_sync

  scope :with_conditions, -> (conditions) { where(conditions) } 
  scope :full_time_support_agents, -> { 
          where(
            occasional: false,
            agent_type: SUPPORT_AGENT_TYPE,
            'users.deleted': false
          )}
  scope :occasional_agents, -> {
    where(
      occasional: true,
      'users.deleted': false
    )
  }

  scope :list, -> { includes(:user).order(:name) }

  xss_sanitize :only => [:signature_html],  :html_sanitize => [:signature_html]
  
  def self.technician_list account_id  
    User.joins(:agent).where(account_id: account_id, deleted: false).order('name')
  end

  def all_ticket_permission
    ticket_permission == PERMISSION_KEYS_BY_TOKEN[:all_tickets]
  end

  def reset_ticket_permission
    self.ticket_permission = PERMISSION_KEYS_BY_TOKEN[:all_tickets]
  end

  def ticket_permission_token
    PERMISSION_TOKENS_BY_KEY[self.ticket_permission]
  end

  def field_agent_check_using_cache?
    Account.current.agent_types_from_cache.find { |type| type.name == Agent::FIELD_AGENT }.try(&:agent_type_id) == agent_type
  end

  def signature_htm
    self.signature_html
  end

  def full_time_support_agent?
    support_agent? && !occasional
  end

  def within_agent_limit?(agent_count)
    account.subscription.agent_limit && account.subscription.agent_limit >= agent_count
  end

  def increment_agent_count_in_redis(key)
    increment_others_redis(key).to_i
  end

  def push_agent_count_in_redis(key)
    incremented_agent_count = account.full_time_support_agents.count + 1
    unless set_others_redis_with_expiry(key, incremented_agent_count, { ex: AGENT_LIMIT_KEY_EXPIRY, nx: true })
      incremented_agent_count = increment_agent_count_in_redis(key)
    end
    incremented_agent_count
  end

  def get_incremented_agent_count(key)
    return increment_agent_count_in_redis(key) if redis_key_exists?(key)

    push_agent_count_in_redis(key)
  end

  def check_if_agent_limit_reached?
    if account.subscription.state.casecmp('active').zero?
      key = agents_count_key
      incremented_agent_count = get_incremented_agent_count(key)
      @agent_count_incremented = true
      unless within_agent_limit?(incremented_agent_count)
        errors.add(:base, I18n.t('maximum_agents_msg'))
        raise ActiveRecord::RecordInvalid, self
      end
    end
  end

  def agents_count_key
    format(AGENTS_COUNT_KEY, account_id: account_id.to_s)
  end

  def decrement_agent_count_in_redis
    decrement_others_redis(agents_count_key) if @agent_count_incremented || agent_deleted_when_agent_count_key_exists?
  end

  def change_points score
    # Assign points to agent if no point have been given before
    # Else increment the existing points total by the given amount
    if self.points.nil?
      Agent.where(id: id).update_all("points = #{score.to_i}")
    else
      Agent.where(id: id).update_all("points = points + #{score.to_i}")
    end
  end

  #for user_emails
  # def only_primary_email
  #   self.errors.add(:base, I18n.t('activerecord.errors.messages.agent_email')) unless (self.user.user_emails.length == 1)
  # end

  # State => Fulltime, Occational or Deleted
  #
  def self.filter(type, state = "active", letter="", order = "name", order_type = "ASC", page = 1, per_page = 20)
    order = "name" unless order && AgentsHelper::AGENT_SORT_ORDER_COLUMN.include?(order.to_sym)
    order_type = "ASC" unless order_type && AgentsHelper::AGENT_SORT_ORDER_TYPE.include?(order_type.to_sym)
    where(filter_condition(state,letter,type)).includes(user: :avatar).order("#{order} #{order_type}").paginate(per_page: per_page, page: page)
  end

  def self.filter_condition(state, letter, type)
    unless "deleted".eql?(state)
      return ["users.deleted = ? and agents.occasional = ? and users.name like ? and agents.agent_type = ?", false, "occasional".eql?(state),"#{letter}%",type]
    else
      return ["users.deleted = ?", true]
    end
  end

  def assumable_agents
    account.agents_from_cache.map do |agent|
      agent.user if user.can_assume?(agent.user)
    end.compact
  end

  def toggle_availability?
    return false unless account.features?(:round_robin) || account.agent_statuses_enabled?

    account.agent_statuses_enabled? ? allow_status_toggle? : allow_availability_toggle?
  end

  def group_ticket_permission
    ticket_permission == PERMISSION_KEYS_BY_TOKEN[:group_tickets]
  end

  def assigned_ticket_permission
    ticket_permission == PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]
  end

  def signature_value
    self.signature_html || (RedCloth.new(self.signature).to_html unless @signature.blank?)
  end
  
  def parsed_signature(placeholder_params)
    Liquid::Template.parse(signature_value.to_s).render(placeholder_params)
  end

  def next_level
    return unless points?
    user.account.scoreboard_levels.next_level_for_points(points).first
  end

  def remove_escalation
    Group.where(account_id: account_id, escalate_to: user_id).update_all(escalate_to: nil, assign_time: nil)
    clear_group_cache
  end

  def save_deleted_agent_info
    @deleted_model_info = central_publish_payload
  end

  def clear_group_cache
    MemcacheKeys.delete_from_cache(ACCOUNT_GROUPS % { :account_id =>self.account_id })
  end

  def agent_url
    "#{account.full_url}/api/v2/agents/#{user_id}"
  end

  def to_xml(options = {})
    options.merge!(API_OPTIONS)
    super(options)
  end

  def as_json(options = {})
    options.merge!(API_OPTIONS)
    super options
  end

  def create_model_changes
    @model_changes = self.changes.clone.to_hash
    @model_changes.symbolize_keys!
  end

  def enqueue_round_robin_process
    return unless @model_changes.key?(:available)
    Groups::ToggleAgentFromGroups.perform_async({:user_id => self.user_id})
  end

  def sync_skill_based_queues
    if account.skill_based_round_robin_enabled? && @model_changes.key?(:available)
      SBRR::Toggle::User.perform_async(:user_id => user_id)
    end
  end

  def sync_agent_availability_to_ocr
    OmniChannelRouting::AgentSync.perform_async(user_id: user_id, availability: available)
  end

  def nullify_tickets
    reset_responder_form_tickets
    reset_internal_agent_from_tickets
    reset_responder_from_archive_tickets
  end

  def reset_responder_form_tickets
    Helpdesk::ResetResponder.perform_async(user_id: user_id, reason: { delete_agent: [user_id] })
  end

  def reset_internal_agent_from_tickets
    Helpdesk::ResetInternalAgent.perform_async(internal_agent_id: user_id, reason: { delete_internal_agent: [user_id] }) if Account.current.shared_ownership_enabled?
  end

  def reset_responder_from_archive_tickets
    Helpdesk::ResetArchiveTickets.perform_async(user_id: user_id) if Account.current.features_included?(:archive_tickets)
  end

  def reset_gamification
    destroy_achieved_quests
    destroy_support_scores
    reset_to_beginner_level
  end

  def update_last_active(force=false)
    touch(:last_active_at) if force or last_active_at.nil? or ((Time.now - last_active_at) > 4.hours)
  end

  def update_active_since
    self.active_since = Time.now.utc if available_changed?
  end

  def current_load group
    agent_key = group.round_robin_agent_capping_key(user_id)
    count = get_round_robin_redis(agent_key)
    count = count.to_i unless count.nil?
    [count, agent_key]
  end

  def assign_next_ticket group
    key = group.round_robin_capping_key
    capping_condition, ticket, ticket_id = nil
    MAX_CAPPING_RETRY.times do
      ticket_id = group.lpop_from_rr_capping_queue

      Rails.logger.debug "RR popped ticket : #{ticket_id}"
      
      return unless ticket_id.present?
      ticket = group.tickets.find_by_display_id(ticket_id)
      capping_condition = ticket.present? && ticket.capping_ready?
      break if capping_condition
    end
    
    if capping_condition
      MAX_CAPPING_RETRY.times do
        ticket_count, agent_key = current_load(group)
  
        if ticket_count.present? && ticket_count < group.capping_limit
          self.reload
          unless self.available?
            group.remove_agent_from_group_capping(self.user_id)
            break
          end
          watch_round_robin_redis(agent_key)
          new_score = generate_new_score(ticket_count + 1) #gen new score with the updated ticket count value
          result    = group.update_agent_capping_with_lock user_id, new_score

          if result.is_a?(Array) && result[1].present?
            Rails.logger.debug "RR SUCCESS Agent's next ticket : #{ticket.display_id} - 
                              #{user_id}, #{group.id}, #{new_score}, #{result.inspect}".squish
            ticket.responder_id = user_id
            ticket.round_robin_assignment = true
            ticket.set_round_robin_activity
            ticket.save
            return true
          end
          Rails.logger.debug "RR FAILED Agent's next ticket : #{ticket.display_id} - 
                              #{user_id}, #{group.id}, #{new_score}, #{result.inspect}".squish
        elsif ticket_count.nil?
          Rails.logger.debug "RR FAILED Agent not in redis #{ticket.display_id} #{user_id}, #{group.id}"
          break                        
        end
        Rails.logger.debug "Looping again for ticket : #{ticket.display_id}"
      end
    end
    group.lpush_to_rr_capping_queue(ticket_id) if capping_condition
    false
  end

  def contribution_group_ids
    agent_group = all_agent_groups_from_cache.select { |ag| ag.write_access.blank? }
    agent_group.map(&:group_id).sort
  end

  def agent_contribution_group_ids
    agent_group = Account.current.contribution_agent_groups_from_cache(user_id)
    group_ids = agent_group.map(&:group_id).sort
    Rails.logger.info "AdvancedScope :: ContributionAgentGroups :: UserID::#{user_id} :: Groups :: #{group_ids}"
    group_ids
  end

  def valid_groups_ids
    @valid_groups_ids ||= Account.current.groups_from_cache.map(&:id).sort
  end

  def build_agent_groups_attributes(group_ids, contribution_group_ids = nil)
    return if !group_ids.is_a?(Array) && !contribution_group_ids.is_a?(Array)

    group_ids, contribution_group_ids = sanitize_agent_group_params(group_ids, contribution_group_ids)
    db_agent_groups = new_record? ? [] : all_agent_groups
    mark_destroy_for_old_agent_groups(db_agent_groups, group_ids, contribution_group_ids) unless new_record?
    update_agent_group_list(db_agent_groups, group_ids) if group_ids.is_a?(Array)
    update_agent_group_list(db_agent_groups, contribution_group_ids, false) if contribution_group_ids.is_a?(Array)
  end

  def update_agent_group_list(all_agent_groups, group_ids, write_access = true)
    group_ids &= valid_groups_ids
    collect_new_ids = []
    group_ids.each do |group_id|
      agent_group = all_agent_groups.bsearch { |ag| group_id <=> ag.group_id }
      agent_group.blank? ? (collect_new_ids << group_id) : (agent_group.write_access = write_access)
    end
    collect_new_ids.each do |group_id|
      agent_group = self.all_agent_groups.build(group_id: group_id, write_access: write_access)
      agent_group.instance_variable_set(:@marked_for_destruction, false) # in case of scope get to all ticket permission
    end
  end

  def mark_destroy_for_old_agent_groups(all_agent_groups, group_ids, contribution_group_ids)
    if group_ids.is_a?(Array) && contribution_group_ids.is_a?(Array)
      exclude_ids = contribution_group_ids + group_ids
      all_agent_groups.reject { |ag| exclude_ids.include?(ag.group_id) }.each(&:mark_for_destruction)
    elsif group_ids.is_a?(Array)
      all_agent_groups.reject { |ag| group_ids.include?(ag.group_id) || ag.write_access.blank? }.each(&:mark_for_destruction)
    elsif contribution_group_ids.is_a?(Array)
      all_agent_groups.reject { |ag| ag.write_access.present? || contribution_group_ids.include?(ag.group_id) }.each(&:mark_for_destruction)
    end
  end

  def sanitize_agent_group_params(group_ids, contributing_group_ids)
    group_ids.map!(&:to_i).compact! if group_ids.is_a?(Array)
    contributing_group_ids.map!(&:to_i).compact! if contributing_group_ids.is_a?(Array)

    [group_ids, contributing_group_ids]
  end

  def destroy_contribution_group_on_permission_change
    all_agent_groups.select { |ag| ag.write_access.blank? }.each(&:mark_for_destruction) unless changes[:ticket_permission][1] == PERMISSION_KEYS_BY_TOKEN[:group_tickets]
  end

  def field_agent?
    self.agent_type == AgentType.agent_type_id(Agent::FIELD_AGENT)
  end

  def fetch_valid_groups
    agent_type_name = AgentType.agent_type_name(self.agent_type)
    group_type_name = Agent::AGENT_GROUP_TYPE_MAPPING[agent_type_name]
    group_type_id = GroupType.group_type_id(group_type_name)
    Account.current.groups_from_cache.select { |group| group.group_type == group_type_id }
  end

  def support_agent?
    agent_type == Admin::AdvancedTicketing::FieldServiceManagement::Constant::SUPPORT_AGENT_TYPE
  end

  def agent_availability
    return old_agent_availability if return_old_agent_availability

    unless available
      out_of_office.is_a?(Integer) ? Agent::OUT_OF_OFFICE : Agent::UN_AVAILABLE
    end
  end

  def out_of_office
    return unless Account.current.out_of_office_enabled?

    begin
      user.make_current
      request_options = { url: OUT_OF_OFFICE_INDEX + format(QUERY_PARAM, state_value: 'active'), action_method: :index }
      ooo_response = perform_shift_request(nil, nil, true, request_options)
      return if ooo_response[:body].blank? || ooo_response[:code] != 200 || ooo_response[:body]['data'].blank?

      @out_of_office_days = (ooo_response[:body]['data'][0]['end_time'].to_datetime - ooo_response[:body]['data'][0]['start_time'].to_datetime).to_i
    rescue StandardError => e
      Rails.logger.debug "error while computing ooo: #{e.inspect}"
    ensure
      User.reset_current_user
    end
  end

  def agent_freshcaller_enabled?
    freshcaller_agent.try(:fc_enabled) || false
  end

  def agent_freshchat_enabled?
    self.additional_settings.try(:[], :freshchat).try(:[], :enabled) || false
  end

  def publish_update_central_payload(model_changes)
    @model_changes = model_changes
    self.manual_publish_to_central(nil, :update, nil, false)
  end

  protected
    # adding the agent role ids through virtual attr agent_role_ids.
    # reason is this callback is getting executed before user roles update.
  def update_agent_to_livechat
    site_id = account.chat_setting.site_id
    # role_ids = self.agent_role_ids.null? self.user.roles.collect{ |role| role.id} : self.agent_role_ids
    # :roles => role_ids, need to add in phase 2 for chat privilages
    if account.features?(:chat) && site_id && !(::User.current.blank?)
      c = {:name=>self.user.name, :agent_id=>self.user.id, :site_id => site_id,
           :scope => SCOPE_TOKENS_BY_KEY[self.ticket_permission]}
      LivechatWorker.perform_async({:worker_method =>"create_agent",
                                        :siteId => site_id, :agent_data => [c].to_json})
    end
  end

  #Will be only called during disabling FSM via API(automations). Customers can not disable FSM from UI
  def self.destroy_agents(account, type) 
    agents = account.agents.where(agent_type: type).includes(:user).all
    agents.each do |agent|
      agent.user.make_customer
    end
  end

  private

  def allow_availability_toggle?
    self.groups.round_robin_groups.exists? &&
      self.groups.round_robin_groups.disallowing_toggle_availability.count('1') == 0
  end

  def check_field_agent_groups?
    account.field_service_management_enabled? && all_agent_groups.present? && field_agent?
  end

  def reset_to_beginner_level
    beginner = Account.current.scoreboard_levels.least_points.first
    self.points = beginner.points
    self.save
    SupportScore.add_agent_levelup_score(self.user, beginner.points)
  end

  def destroy_achieved_quests
    self.achieved_quests.destroy_all
  end

  def destroy_support_scores
    self.support_scores.destroy_all
  end

  def agent_destroy_cleanup
    AgentDestroyCleanup.perform_async({:user_id => self.user_id})
  end
  
  def validate_signature
    begin
      Liquid::Template.parse(signature_value.presence)
    rescue
      errors.add(:base, I18n.t('agent.invalid_placeholder'))
    end
  end

  # Used by API V2
  def self.api_filter(agent_filter)
    {
      occasional: {
        conditions: { occasional: true }
      },
      fulltime: {
        conditions: { occasional: false }
      },
      email: {
        conditions: [ "users.email = ? ", agent_filter.email ]
      },
      phone: {
        conditions: [ "users.phone = ? ", agent_filter.phone ]
      },
      mobile: {
        conditions: [ "users.mobile = ? ", agent_filter.mobile ]
      },

      type: {
        conditions: { agent_type: AgentType.agent_type_id(agent_filter.type) }
      },
      group_id: {
        conditions: ['agent_groups.group_id = ? ', agent_filter.group_id],
        joins: :agent_groups
      }
    }
  end

  def mark_unavailable
    !(self.available = false)
  end

  def build_agent_groups_hash(group_id, id = nil)
    {:id => id, :group_id => group_id, :_destroy => id.present?}
  end

  def central_group_key_names(agent_group)
    CENTRAL_GROUP_KEYS[agent_group.write_access.present? ? 0 : 1]
  end

  def touch_agent_group_change(agent_group)
    return if agent_group.group_id.blank?

    initialize_group_changes
    agent_info = { id: agent_group.group_id, name: agent_group.group.name }
    deleted = agent_group.destroyed? || agent_group.marked_for_destruction? ? 1 : 0
    group_changes[central_group_key_names(agent_group)][CENTRAL_ADD_REMOVE_KEY[deleted]] << agent_info
    clear_group_cache
  end

  def initialize_group_changes
    self.group_changes ||= {}
    CENTRAL_GROUP_KEYS.each do |key|
      group_changes[key] ||= {}
      group_changes[key][:added] ||= []
      group_changes[key][:removed] ||= []
    end
  end

  def update_agent_group_change
    all_agent_groups.each do |agent_group|
      next if agent_group.new_record? || agent_group.marked_for_destruction? || agent_group.group_id.blank? || !agent_group.write_access_changed?

      agent_info = { id: agent_group.group_id, name: agent_group.group.name }
      initialize_group_changes
      key = central_group_key_names(agent_group)
      group_changes[key][:added] << agent_info
      group_changes[CENTRAL_GROUP_KEYS[key == :groups ? 1 : 0]][:removed] << agent_info
    end
  end

  def set_default_type_if_needed
    self.agent_type = AgentType.agent_type_id(SUPPORT_AGENT) unless self.agent_type
  end

  def check_agent_type_changed
    if agent_type_changed?
      self.errors[:agent_type] << :agent_type_change_not_allowed 
      return false
    end
    true
  end

  # checking whether field agent has only field groups associated
  def validate_field_agent_groups
    invalid_groups = self.all_agent_groups.map(&:group_id) - fetch_valid_groups.map(&:id)
    if invalid_groups.present?
      self.errors.add(:group_ids, ErrorConstants::ERROR_MESSAGES[:should_not_be_support_group])
      return false
    end
    true
  end

  def check_ticket_permission
    if field_agent? && !ALLOWED_PERMISSION_FOR_FIELD_AGENT.include?(self.ticket_permission)
      self.errors[:ticket_permission] << ErrorConstants::ERROR_MESSAGES[:field_agent_scope]
      return false
    end
    true
  end

  def validate_field_agent_state
    self.errors[:occasional] << ErrorConstants::ERROR_MESSAGES[:field_agent_state] if field_agent? && occasional?
  end

  def allow_ocr_sync?
    account.omni_channel_routing_enabled? && @model_changes.key?(:available) && !ocr_update
  end

  def agent_deleted_when_agent_count_key_exists?
    transaction_include_action?(:destroy) && redis_key_exists?(agents_count_key)
  end

  def allow_status_toggle?
    groups.present? && groups.disallowing_toggle_availability.count.zero?
  end
end
