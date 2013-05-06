class Agent < ActiveRecord::Base
  
  belongs_to_account
  include Notifications::MessageBroker
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
  
  before_create :set_default_ticket_permission
  before_update :update_agents_level
  before_create :set_account_id

  after_save  :update_agent_levelup
  after_update :publish_game_notifications
  
  TICKET_PERMISSION = [
    [ :all_tickets, 1 ], 
    [ :group_tickets,  2 ], 
    [ :assigned_tickets, 3 ]
  ]
 
  named_scope :with_conditions ,lambda {|conditions| { :conditions => conditions} }
  named_scope :full_time_agents, :conditions => { :occasional => false, 'users.deleted' => false}
  named_scope :occasional_agents, :conditions => { :occasional => true, 'users.deleted' => false}
  
  PERMISSION_TOKENS_BY_KEY = Hash[*TICKET_PERMISSION.map { |i| [i[1], i[0]] }.flatten]
  PERMISSION_KEYS_BY_TOKEN = Hash[*TICKET_PERMISSION.map { |i| [i[0], i[1]] }.flatten]
  
  def self.technician_list account_id
    
    agents = User.find(:all, :joins=>:agent, :conditions => {:account_id=>account_id, :deleted =>false} , :order => 'name')    
  
end

def all_ticket_permission
  ticket_permission == PERMISSION_KEYS_BY_TOKEN[:all_tickets]
end

def group_ticket_permission
  ticket_permission == PERMISSION_KEYS_BY_TOKEN[:group_tickets]
end

def set_default_ticket_permission
  self.ticket_permission = PERMISSION_KEYS_BY_TOKEN[:all_tickets] if self.ticket_permission.blank?
end

def signature_value
  self.signature_html || (RedCloth.new(self.signature).to_html unless @signature.blank?)
end

  named_scope :list , lambda {{ :include => :user , :order => :name }}                                                   

  def next_level
    return unless points?
    user.account.scoreboard_levels.next_level_for_points(points).first
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

protected
  
  def update_agents_level
    return unless points_changed?

    level = user.account.scoreboard_levels.level_for_score(points).first
    if level and !(scoreboard_level_id.eql? level.id)
      self.level = level
    end
  end

  def publish_game_notifications
    level_change = scoreboard_level_id_changed? && scoreboard_level_id_change 
    level_up = level_change && ( level_change[0].nil? || level_change[0] < level_change[1] )
    if level_up
      publish("#{I18n.t('gamification.notifications.newlevel',:name => level.name)}", [user_id.to_s]) 
    end
  end

  def update_agent_levelup
    return unless scoreboard_level_id_changed?
    new_point = user.account.scoreboard_levels.find(scoreboard_level_id).points
    if level and ((points ? points : 0) < new_point)
      SupportScore.add_agent_levelup_score(user, new_point)
    end 
  end

  def set_account_id
    account_id = user.account_id
  end

end
