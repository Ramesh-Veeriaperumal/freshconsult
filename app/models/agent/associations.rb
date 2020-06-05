class Agent < ActiveRecord::Base

  belongs_to_account
  
  belongs_to :user, :class_name =>'User', :foreign_key =>'user_id'

  delegate :name, to: :user

  belongs_to :level, :class_name => 'ScoreboardLevel', :foreign_key => 'scoreboard_level_id'

  # ActiveRecord::HasManyThroughCantAssociateThroughHasOneOrManyReflection: 
  # Cannot modify association 'Agent#agent_groups' because the source reflection class 'Agent' is 
  # associated to 'User' via :has_one.  
  # Changing since got problem when deleting an agent in Rails3
  has_many :agent_groups,
           class_name: 'AgentGroup',
           foreign_key: 'user_id',
           primary_key: 'user_id',
           dependent: :destroy,
           after_add: :touch_agent_group_change,
           after_remove: :touch_agent_group_change,
           conditions: { write_access: true }

  has_many :groups, :through => :agent_groups, :dependent => :destroy

  has_many :all_agent_groups,
           class_name: 'AgentGroup',
           foreign_key: :user_id,
           primary_key: :user_id,
           autosave: true,
           dependent: :destroy,
           after_add: :touch_agent_group_change,
           after_remove: :touch_agent_group_change,
           order: :group_id  
  
  # ActiveRecord::HasManyThroughCantAssociateThroughHasOneOrManyReflection: Cannot modify association 
  # 'Agent#time_sheets' because the source reflection class 'Agent' is associated to 'User' via :has_one
  # Same issue as above for both create and delete
  has_many :time_sheets, :class_name => 'Helpdesk::TimeSheet' ,  
          :foreign_key =>'user_id', :primary_key => "user_id"

  has_many :achieved_quests, :foreign_key =>'user_id', :primary_key => "user_id",
          :dependent => :delete_all

  has_many :support_scores, foreign_key: 'user_id', primary_key: 'user_id'

  has_many :tickets, :class_name => 'Helpdesk::Ticket', :foreign_key =>'responder_id', 
          :primary_key => "user_id"

  has_one :freshcaller_agent, class_name: 'Freshcaller::Agent', dependent: :destroy

end
