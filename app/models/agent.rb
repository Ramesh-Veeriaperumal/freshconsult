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

  VERSION_MEMBER_KEY = 'AGENTS_GROUPS_LIST'.freeze

  concerned_with :associations, :constants, :presenter

  publishable on: [:create, :update, :destroy]

  before_destroy :remove_escalation, :save_deleted_agent_info

  accepts_nested_attributes_for :user
  accepts_nested_attributes_for :agent_groups, :allow_destroy => true
  before_update :update_active_since, :create_model_changes
  before_create :mark_unavailable
  after_commit :enqueue_round_robin_process, on: :update
  after_commit :sync_skill_based_queues, on: :update
  after_commit :sync_agent_availability_to_ocr, on: :update, if: :allow_ocr_sync?

  after_commit :nullify_tickets, :agent_destroy_cleanup, on: :destroy
  
  after_commit  ->(obj) { obj.update_agent_to_livechat } , on: :create
  after_commit  ->(obj) { obj.update_agent_to_livechat } , on: :update  
  before_save :set_default_type_if_needed, on: [:create, :update]

  validates_presence_of :user_id
  validate :validate_signature
  validate :check_agent_type_changed, on: :update
  validate :validate_field_agent_groups, if: :check_field_agent_groups?
  validate :check_ticket_permission, :validate_field_agent_state, if: -> { account.field_service_management_enabled? }
  # validate :only_primary_email, :on => [:create, :update] moved to user.rb

  attr_accessible :signature_html, :user_id, :ticket_permission, :occasional, :available, :shortcuts_enabled,
                  :scoreboard_level_id, :user_attributes, :group_ids, :freshchat_token, :agent_type, :search_settings, :focus_mode
  attr_accessor :agent_role_ids, :freshcaller_enabled, :user_changes, :group_changes, :ocr_update, :misc_changes

  scope :with_conditions ,lambda {|conditions| { :conditions => conditions} }
  scope :full_time_support_agents, :conditions => { :occasional => false, :agent_type => SUPPORT_AGENT_TYPE, 'users.deleted' => false}
  scope :occasional_agents, :conditions => { :occasional => true, 'users.deleted' => false }
  scope :list , lambda {{ :include => :user , :order => :name }}  

  xss_sanitize :only => [:signature_html],  :html_sanitize => [:signature_html]
  
  def self.technician_list account_id  
    agents = User.find(:all, :joins=>:agent, :conditions => {:account_id=>account_id, :deleted =>false} , :order => 'name')  
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

  def signature_htm
    self.signature_html
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
    paginate :per_page => per_page,
      :page => page,
      :include => { :user => :avatar },
      :conditions => filter_condition(state,letter,type),
      :order => "#{order} #{order_type}"
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
    return false unless account.features?(:round_robin)
    allow_availability_toggle? ? true : false
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
    Group.update_all({:escalate_to => nil, :assign_time => nil},{:account_id => account_id, :escalate_to => user_id})
    clear_group_cache
  end

  def save_deleted_agent_info
    @deleted_model_info = central_publish_payload
  end

  def clear_group_cache
    MemcacheKeys.delete_from_cache(ACCOUNT_GROUPS % { :account_id =>self.account_id })
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

  def build_agent_groups_attributes(group_list)
    return unless group_list.is_a?(Array)
    old_group_ids    = self.new_record? ? [] : self.agent_groups.pluck(:group_id)
    group_list      = group_list.map(&:to_i)
    add_group_ids    = Account.current.groups.where(:id => group_list - old_group_ids).pluck(:id)
    delete_group_ids = old_group_ids - group_list

    agent_groups_array = []
    if delete_group_ids.present?
      agent_groups.where(:group_id => delete_group_ids).map { |agent_group|
        agent_groups_array << build_agent_groups_hash(agent_group.group_id, agent_group.id)
      }
    end
    if add_group_ids.present?
      multiple_agents_added = add_group_ids.count > 1
      add_group_ids.map { |group_id|
        agent_groups_array << build_agent_groups_hash(group_id)
      }
    end
    self.agent_groups_attributes = agent_groups_array if agent_groups_array.present?
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
    account.field_service_management_enabled? && self.agent_groups.present? && field_agent?
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

  def touch_agent_group_change(agent_group)
    return unless agent_group.group_id.present?
    agent_info = { id: agent_group.group_id, name: agent_group.group.name }
    if self.group_changes.present?
      self.group_changes.push(agent_info)
    else
      self.group_changes = [agent_info]
    end
    clear_group_cache
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
    invalid_groups = self.agent_groups.map(&:group_id) - fetch_valid_groups.map(&:id)
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
end
