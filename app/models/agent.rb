class Agent < ActiveRecord::Base
  self.primary_key = :id
  self.table_name = :agents

  include Cache::Memcache::Agent
  include Agents::Preferences
  include Social::Ext::AgentMethods
  include Chat::Constants
  include Redis::RoundRobinRedis
  include RoundRobinCapping::Methods

  concerned_with :associations, :constants

  before_destroy :remove_escalation

  accepts_nested_attributes_for :user
  before_update :create_model_changes
  before_create :mark_unavailable
  after_commit :enqueue_round_robin_process, on: :update

  after_commit :nullify_tickets, :agent_destroy_cleanup, on: :destroy
  
  after_commit  ->(obj) { obj.update_agent_to_livechat } , on: :create
  after_commit  ->(obj) { obj.update_agent_to_livechat } , on: :update
  validates_presence_of :user_id
  validate :validate_signature
  # validate :only_primary_email, :on => [:create, :update] moved to user.rb

  attr_accessible :signature_html, :user_id, :ticket_permission, :occasional, :available, :shortcuts_enabled,
    :scoreboard_level_id, :user_attributes, :group_ids

  attr_accessor :agent_role_ids

  scope :with_conditions ,lambda {|conditions| { :conditions => conditions} }
  scope :full_time_agents, :conditions => { :occasional => false, 'users.deleted' => false}
  scope :occasional_agents, :conditions => { :occasional => true, 'users.deleted' => false}
  scope :list , lambda {{ :include => :user , :order => :name }}  

  xss_sanitize :only => [:signature_html],  :html_sanitize => [:signature_html]
  
  def self.technician_list account_id  
    agents = User.find(:all, :joins=>:agent, :conditions => {:account_id=>account_id, :deleted =>false} , :order => 'name')  
  end

  def all_ticket_permission
    ticket_permission == PERMISSION_KEYS_BY_TOKEN[:all_tickets]
  end

  def signature_htm
    self.signature_html
  end

  def change_points score
  	# Assign points to agent if no point have been given before
  	# Else increment the existing points total by the given amount
  	if self.points.nil?
  		Agent.where(:id => self.id).update_all("points = #{score}")
  	else
  		Agent.where(:id => self.id).update_all("points = points + #{score}")
  	end
  end

  #for user_emails
  # def only_primary_email
  #   self.errors.add(:base, I18n.t('activerecord.errors.messages.agent_email')) unless (self.user.user_emails.length == 1)
  # end

  # State => Fulltime, Occational or Deleted
  #
  def self.filter(state = "active",letter="", order = "name", order_type = "ASC", page = 1, per_page = 20)
    order = "name" unless order && AgentsHelper::AGENT_SORT_ORDER_COLUMN.include?(order.to_sym)
    order_type = "ASC" unless order_type && AgentsHelper::AGENT_SORT_ORDER_TYPE.include?(order_type.to_sym)
    paginate :per_page => per_page,
      :page => page,
      :include => { :user => :avatar },
      :conditions => filter_condition(state,letter),
      :order => "#{order} #{order_type}"
  end

  def self.filter_condition(state,letter)
    unless "deleted".eql?(state)
      return ["users.deleted = ? and agents.occasional = ? and users.name like ?", false, "occasional".eql?(state),"#{letter}%"]
    else
      return ["users.deleted = ?", true]
    end
  end

  def assumable_agents
    account.agents_from_cache.map do |agent|
      agent.user if user.can_assume?(agent.user)
    end.compact
  end

  def allow_availability_toggle?
    !self.groups.empty? && self.groups.where(:toggle_availability => false, :ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:round_robin]).count('1') == 0
  end

  def in_round_robin?
    self.agent_groups.count(:conditions => ['ticket_assign_type = ?',
                                             Group::TICKET_ASSIGN_TYPE[:round_robin]], :joins => :group) > 0
  end

  def toggle_availability?
    return false if(!account.features?(:round_robin) || !in_round_robin?)
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
    Resque.enqueue(Helpdesk::ToggleAgentFromGroups,
                   { :account_id => account.id,
                     :user_id => self.user_id })
  end

  def nullify_tickets
    reason = {:delete_agent => [self.user_id]}
    Helpdesk::ResetResponder.perform_async({:user_id => self.user_id, :reason => reason})
  end
  
  def reset_gamification
    destroy_achieved_quests
    destroy_support_scores
    reset_to_beginner_level
  end

  def update_last_active(force=false)
    touch(:last_active_at) if force or last_active_at.nil? or ((Time.now - last_active_at) > 4.hours)
  end

  def current_load group
    agent_key = group.round_robin_agent_capping_key(user_id)
    [get_round_robin_redis(agent_key).to_i, agent_key]
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
  
        if ticket_count < group.capping_limit
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
        end
        Rails.logger.debug "Looping again for ticket : #{ticket.display_id}"
      end
    end
    group.lpush_to_rr_capping_queue(ticket_id) if capping_condition
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

  private

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
      }
    }
  end

  def mark_unavailable
    !(self.available = false)
  end

end
