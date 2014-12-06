class Agent < ActiveRecord::Base
  
  include ArExtensions
  include Cache::Memcache::Agent
  include Agents::Preferences
  include Social::Ext::AgentMethods

  concerned_with :associations, :constants

  before_destroy :remove_escalation

  accepts_nested_attributes_for :user
  before_update :create_model_changes
  after_commit_on_update :enqueue_round_robin_process
  
  validates_presence_of :user_id
  # validate :only_primary_email, :on => [:create, :update] moved to user.rb
  xss_sanitize :only => [:signature_html],  :html_sanitize => [:signature_html]
  attr_accessible :signature_html, :user_id, :ticket_permission, :occasional, :available, :shortcuts_enabled

  named_scope :with_conditions ,lambda {|conditions| { :conditions => conditions} }
  named_scope :full_time_agents, :conditions => { :occasional => false, 'users.deleted' => false}
  named_scope :occasional_agents, :conditions => { :occasional => true, 'users.deleted' => false}
  named_scope :list , lambda {{ :include => :user , :order => :name }}  
  
  def self.technician_list account_id  
    agents = User.find(:all, :joins=>:agent, :conditions => {:account_id=>account_id, :deleted =>false} , :order => 'name')  
  end

  def all_ticket_permission
    ticket_permission == PERMISSION_KEYS_BY_TOKEN[:all_tickets]
  end

  def signature_htm
    self.signature_html
  end

  #for user_emails
  # def only_primary_email
  #   self.errors.add(:base, I18n.t('activerecord.errors.messages.agent_email')) unless (self.user.user_emails.length == 1)
  # end

  # State => Fulltime, Occational or Deleted
  # 
  def self.filter(state = "active",letter="", order = "name", order_type = "ASC", page = 1, per_page = 20)
    order = "name" unless order
    order_type = "ASC" unless order_type
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

  #This method returns true if atleast one of the groups that he belongs to has round robin feature
  def in_round_robin?
    return self.agent_groups.count(:conditions => ['ticket_assign_type = ?', 
            Group::TICKET_ASSIGN_TYPE[:round_robin]], :joins => :group) > 0
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
    @model_changes = self.changes.clone
    @model_changes.symbolize_keys!
  end

  def enqueue_round_robin_process
    return unless @model_changes.key?(:available)
    Resque.enqueue(Helpdesk::ToggleAgentFromGroups, 
          { :account_id => account.id,
            :user_id => self.user_id })
  end

end
