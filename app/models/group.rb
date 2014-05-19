class Group < ActiveRecord::Base
  
  belongs_to_account
  include Cache::Memcache::Group
  include Redis::RedisKeys
  include Redis::OthersRedis

  after_commit :clear_cache

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id
  
   has_many :agent_groups , :class_name => "AgentGroup", :foreign_key => "group_id", :dependent => :destroy
   
   has_many :agents, :through => :agent_groups, :source => :user , :conditions => ["users.deleted=?", false]

   has_many :tickets, :class_name => 'Helpdesk::Ticket', :dependent => :nullify
   has_many :email_configs, :dependent => :nullify
   
   belongs_to :escalate , :class_name => "User", :foreign_key => "escalate_to"
   belongs_to :business_calendar
   
   attr_accessible :name,:description,:email_on_assign,:escalate_to,:assign_time ,:import_id, 
                   :ticket_assign_type, :business_calendar_id
   
   accepts_nested_attributes_for :agent_groups
   named_scope :active_groups_in_account, lambda { |account_id|
     { :joins => "inner join agent_groups on agent_groups.account_id = #{account_id} and
                   agent_groups.group_id = groups.id and groups.account_id = #{account_id}
                   inner join users ON agent_groups.account_id = #{account_id} and
                   agent_groups.user_id = users.id and users.account_id = #{account_id}
                   and users.helpdesk_agent = 1 and users.deleted = 0",
       :group => "agent_groups.group_id" }
    }
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

  TICKET_ASSIGN_TYPE = {:default => 0, :round_robin => 1}

  TICKET_ASSIGN_OPTIONS = [
                            ['group_ticket_options.default',         '0'], 
                            ['group_ticket_options.round_robin',     '1']
                          ]

  ASSIGNTIME_OPTIONS = ASSIGNTIME.map { |i| [i[1], i[2]] }
  ASSIGNTIME_NAMES_BY_KEY = Hash[*ASSIGNTIME.map { |i| [i[2], i[1]] }.flatten]
  ASSIGNTIME_KEYS_BY_TOKEN = Hash[*ASSIGNTIME.map { |i| [i[0], i[2]] }.flatten]
  
  def excluded_agents(account)      
   return account.users.find(:all , :conditions=>['helpdesk_agent = true and id not in (?)',agents.map(&:id)]) unless agents.blank? 
   return account.users.find(:all , :conditions=> { :helpdesk_agent => true })  
  end

  def self.ticket_assign_options
    TICKET_ASSIGN_OPTIONS.map {|t| [I18n.t(t[0]),t[1]]}
  end
	
	def self.online_ivr_performers(group_id)
		# optimize
		return [] if (group = find_by_id(group_id)).blank?
		group.agents.technicians.visible.online_agents
	end
	
	def self.busy_ivr_performers(group_id)
		# optimize
		return [] if (group = find_by_id(group_id)).blank?
		group.agents.technicians.visible.busy_agents
	end

  def all_agents_list(account)
    account.agents_from_cache
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

  def to_xml(options ={})
    options[:indent] ||= 2
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    #options for the user which is included within the groups as agents is set for root node.
    super(:builder=>xml, :skip_instruct => options[:skip_instruct],:include=>{:agents=>{:root=>'agent',:skip_instruct=>true}},:except=>[:account_id,:import_id,:email_on_assign])
  end

  def to_json(options = {})
    #options for user which is included within the groups as agents
    options ={:except=>[:account_id,:email_on_assign,:import_id] ,:include=>{:agents=>{:only=>[:id,:name,:email,:created_at,:updated_at,:active,:customer_id,:job_title,
                    :phone,:mobile,:twitter_id, :description,:time_zone,:deleted,
                    :helpdesk_agent,:fb_profile_id,:external_id,:language,:address] }}}
    super options
  end

  def next_available_agent
    #this method returns the next available agent
    #for the group, provided the group has
    #round robin scheduled.
    return nil if !round_robin_eligible?

    #Take from DB if its not available in redis.
    last_assigned_agent = get_others_redis_key(GROUP_AGENT_TICKET_ASSIGNMENT % 
                                 {:account_id => self.account_id, :group_id => self.id})
    

    if last_assigned_agent.nil?
      agent_ids = self.agents.map { |ag| ag.id  }
    else
      agent_ids = last_assigned_agent.split(",")
    end

    count = 1
    agent_ids.each do |agent_id|
      agent = Agent.find_by_user_id(agent_id)
      next if agent.nil?
      if agent.available?
          #rotating the array. Put the latest assigned agent at last.
          agent_ids = agent_ids.push(agent_ids.shift(count)).flatten
          store_in_redis(agent_ids)
          return agent
      end
      count = count + 1
    end
    return nil

  end

  def store_in_redis(agent_arr)
    set_others_redis_key(GROUP_AGENT_TICKET_ASSIGNMENT % 
            {:account_id => self.account_id, :group_id => self.id}, agent_arr.join(","), false)
  end

  def round_robin_eligible?
    self.account.features?(:round_robin) && (ticket_assign_type == TICKET_ASSIGN_TYPE[:round_robin])
  end
  
end
