class Group < ActiveRecord::Base
  
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id
  
   has_many :agent_groups , :class_name => "AgentGroup", :foreign_key => "group_id"
   
   has_many :agents, :through => :agent_groups, :source => :user , :conditions => ["users.deleted=?", false]
   
   belongs_to :escalate , :class_name => "User", :foreign_key => "escalate_to"
   
   attr_accessible :name,:description,:email_on_assign,:escalate_to,:assign_time ,:import_id
   
   accepts_nested_attributes_for :agent_groups
   liquid_methods :name
  
  
  ASSIGNTIME = [
    [ :half,    I18n.t("group.assigntime.half"),      1800 ], 
    [ :one,     I18n.t("group.assigntime.one"),       3600 ], 
    [ :two,     I18n.t("group.assigntime.two"),       7200 ], 
    [ :four,    I18n.t("group.assigntime.four"),      14400 ], 
    [ :eight,   I18n.t("group.assigntime.eight"),     28800 ], 
    [ :two,     I18n.t("group.assigntime.two"),       43200 ], 
    [ :day,     I18n.t("group.assigntime.day"),       86400 ],
    [ :twoday,  I18n.t("group.assigntime.twoday"),    172800 ], 
    [ :threeday,I18n.t("group.assigntime.threeday"),  259200 ], 
   
   
  ]

  ASSIGNTIME_OPTIONS = ASSIGNTIME.map { |i| [i[1], i[2]] }
  ASSIGNTIME_NAMES_BY_KEY = Hash[*ASSIGNTIME.map { |i| [i[2], i[1]] }.flatten]
  ASSIGNTIME_KEYS_BY_TOKEN = Hash[*ASSIGNTIME.map { |i| [i[0], i[2]] }.flatten]
  
  def self.find_excluded_agents(group_id, account_id)      
    unless group_id.nil?    
      @exclude_list = Agent.find(:all, :joins=>:user, :conditions => "users.account_id=#{account_id} AND users.deleted=#{false} AND users.id NOT IN (select user_id from agent_groups where group_id=#{group_id})" , :order =>'name')   
    else     
      @exclude_list = Agent.find(:all, :joins=>:user, :conditions => "users.account_id=#{account_id} AND users.deleted=#{false}" , :order =>'name')      
    end    
  end
  
  def self.find_included_agents(group_id)    
    @include_list = AgentGroup.find(:all, :joins=>:user, :conditions =>{:group_id =>group_id} )         
    return @include_list    
  end
  
  def agent_emails
    agents.collect { |a| a.email }
  end
  
  def to_liquid
    { 
      "name"  => name,
      "assign_time_mins" => (assign_time || 0).div(60)
    }
  end
  
end
