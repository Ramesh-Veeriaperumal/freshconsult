class Agent < ActiveRecord::Base

  belongs_to_account
  
  belongs_to :user, :class_name =>'User', :foreign_key =>'user_id'

  belongs_to :level, :class_name => 'ScoreboardLevel', :foreign_key => 'scoreboard_level_id'

  has_many :agent_groups, :class_name => 'AgentGroup', :through => :user , 
          :foreign_key =>'user_id', :primary_key => "user_id", :source => :agent, 
          :dependent => :delete_all

  has_many :time_sheets, :class_name => 'Helpdesk::TimeSheet' , :through => :user , 
          :foreign_key =>'user_id', :primary_key => "user_id", :source => :agent

  has_many :achieved_quests, :foreign_key =>'user_id', :primary_key => "user_id",
          :dependent => :delete_all

  has_many :support_scores, :foreign_key =>'user_id', :primary_key => "user_id",
          :dependent => :delete_all

  has_many :tickets, :class_name => 'Helpdesk::Ticket', :foreign_key =>'responder_id', 
          :primary_key => "user_id", :dependent => :nullify

end