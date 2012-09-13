class Agent < ActiveRecord::Base
  
    
  include Notifications::MessageBroker
  belongs_to :user, :class_name =>'User', :foreign_key =>'user_id' , :dependent => :destroy 

  accepts_nested_attributes_for :user
  
  validates_presence_of :user_id
  
  attr_accessible :signature, :user_id , :ticket_permission, :occasional
  
  
  has_many :agent_groups ,:class_name => 'AgentGroup', :through => :user , :foreign_key =>'user_id', :source =>'agents'

  has_many :time_sheets , :class_name => 'Helpdesk::TimeSheet' , :through => :user , :foreign_key =>'user_id'

  belongs_to :level, :class_name => 'ScoreboardLevel', :foreign_key => 'scoreboard_level_id'
  
  before_create :set_default_ticket_permission
  before_update :update_agents_level

  after_save  :update_agent_levelup
  after_update :publish_game_notifications
  
  TICKET_PERMISSION = [
    [ :all_tickets, 1 ], 
    [ :group_tickets,  2 ], 
    [ :assigned_tickets, 3 ]
  ]
 
  
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

named_scope :list , lambda {{ :include => :user , :order => :name }}                                                   

def next_level
  return unless points?
  user.account.scoreboard_levels.next_level_for_points(points).first
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
end
