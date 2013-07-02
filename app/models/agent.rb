class Agent < ActiveRecord::Base
  
  belongs_to_account
  include Cache::Memcache::Agent

  belongs_to :user, :class_name =>'User', :foreign_key =>'user_id'

  accepts_nested_attributes_for :user
  
  validates_presence_of :user_id
  
  attr_accessible :signature_html, :user_id , :ticket_permission, :occasional, :available
  
  
  has_many :agent_groups, :class_name => 'AgentGroup', :through => :user , 
          :foreign_key =>'user_id', :primary_key => "user_id", :source => :agent, 
          :dependent => :delete_all

  has_many :time_sheets, :class_name => 'Helpdesk::TimeSheet' , :through => :user , 
          :foreign_key =>'user_id', :primary_key => "user_id", :source => :agent, 
          :dependent => :delete_all

  has_many :achieved_quests, :foreign_key =>'user_id', :primary_key => "user_id",
          :dependent => :delete_all

  has_many :support_scores, :foreign_key =>'user_id', :primary_key => "user_id",
          :dependent => :delete_all

  has_many :tickets, :class_name => 'Helpdesk::Ticket', :foreign_key =>'responder_id', 
          :primary_key => "user_id", :dependent => :nullify

  belongs_to :level, :class_name => 'ScoreboardLevel', :foreign_key => 'scoreboard_level_id'

  TICKET_PERMISSION = [
    [ :all_tickets, 1 ], 
    [ :group_tickets,  2 ], 
    [ :assigned_tickets, 3 ]
  ]
 
  named_scope :with_conditions ,lambda {|conditions| { :conditions => conditions} }
  named_scope :full_time_agents, :conditions => { :occasional => false, 'users.deleted' => false}
  named_scope :occasional_agents, :conditions => { :occasional => true, 'users.deleted' => false}
  named_scope :list , lambda {{ :include => :user , :order => :name }}
  
  PERMISSION_TOKENS_BY_KEY = Hash[*TICKET_PERMISSION.map { |i| [i[1], i[0]] }.flatten]
  PERMISSION_KEYS_BY_TOKEN = Hash[*TICKET_PERMISSION.map { |i| [i[0], i[1]] }.flatten]
  
  def self.technician_list account_id  
    agents = User.find(:all, :joins=>:agent, :conditions => {:account_id=>account_id, :deleted =>false} , :order => 'name')  
  end

  def all_ticket_permission
    ticket_permission == PERMISSION_KEYS_BY_TOKEN[:all_tickets]
  end

  def signature_htm
    self.signature_html
  end

  # State => Fulltime, Occational or Deleted
  # 
  def self.filter(state = "active", order = "name", order_type = "ASC", page = 1, per_page = 20)
    order = "name" unless order
    order_type = "ASC" unless order_type
    paginate :per_page => per_page, 
             :page => page,
             :include => { :user => :avatar },
             :conditions => filter_condition(state),
             :order => "#{order} #{order_type}"
  end

  def self.filter_condition(state)
    unless "deleted".eql?(state)
      return ["users.deleted = ? and agents.occasional = ?", false, "occasional".eql?(state)]
    else
      return ["users.deleted = ?", true]
    end
  end

  def assumable_agents
    account.users.technicians.select do |agent|
      user.can_assume?(agent)
    end
  end

  #This method returns true if atleast one of the groups that he belongs to has round robin feature
  def in_round_robin?
    return self.agent_groups.count(:conditions => ['ticket_assign_type = ?', 
            Group::TICKET_ASSIGN_TYPE[:round_robin]], :joins => :group) > 0
  end

  def group_ticket_permission
    ticket_permission == PERMISSION_KEYS_BY_TOKEN[:group_tickets]
  end

  def signature_value
    self.signature_html || (RedCloth.new(self.signature).to_html unless @signature.blank?)
  end

  def next_level
    return unless points?
    user.account.scoreboard_levels.next_level_for_points(points).first
  end
end