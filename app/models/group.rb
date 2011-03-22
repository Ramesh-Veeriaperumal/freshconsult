class Group < ActiveRecord::Base
  
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id
  
   has_many :agent_groups , :class_name => "AgentGroup", :foreign_key => "group_id"
   has_many :agents, :through => :agent_groups, :source => :user
   
   belongs_to :escalate , :class_name => "User", :foreign_key => "escalate_to"
   
   attr_accessible :name,:description,:email_on_assign,:escalate_to,:assign_time
   
   accepts_nested_attributes_for :agent_groups
   liquid_methods :name
  
  
  ASSIGNTIME = [
    [ :half,    "30 Minutes",  1800 ], 
    [ :one,     "1 Hour",      3600 ], 
    [ :two,     "2 Hours",      7200 ], 
    [ :four,    "4 Hours",     14400 ], 
    [ :eight,   "8 Hours",     28800 ], 
    [ :two,     "12 Hours",    43200 ], 
    [ :day,     "1 Day",      86400 ],
    [ :twoday,  "2 Days",     172800 ], 
    [ :threeday,"3 Days",     259200 ], 
   
   
  ]

  ASSIGNTIME_OPTIONS = ASSIGNTIME.map { |i| [i[1], i[2]] }
  ASSIGNTIME_NAMES_BY_KEY = Hash[*ASSIGNTIME.map { |i| [i[2], i[1]] }.flatten]
  ASSIGNTIME_KEYS_BY_TOKEN = Hash[*ASSIGNTIME.map { |i| [i[0], i[2]] }.flatten]
  
  def self.find_excluded_agents(group_id, account_id)
    
    
     logger.debug "@exclude_list group_id:: #{group_id} and account_id :: #{account_id}"
    
    unless group_id.nil?
    
      @exclude_list = Agent.find(:all, :joins=>:user, :conditions => "users.account_id=#{account_id} AND users.deleted=#{false} AND users.id NOT IN (select user_id from agent_groups where group_id=#{group_id})")
     
   else
     
      @exclude_list = Agent.find(:all, :joins=>:user, :conditions => "users.account_id=#{account_id} AND users.deleted=#{false}")
      
          
    end
   
   
   
  end
  
  def self.find_included_agents(group_id)
    
    @include_list = AgentGroup.find(:all, :joins=>:user, :conditions =>{:group_id =>group_id} )    
        
    return @include_list
    
  end
  
  def agent_emails
    agents.collect { |a| a.email }
  end
  
end
