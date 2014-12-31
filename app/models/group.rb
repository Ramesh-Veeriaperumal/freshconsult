class Group < ActiveRecord::Base
  self.primary_key = :id
  
  xss_sanitize  :only => [:name, :description], :plain_sanitizer => [:name, :description]
  belongs_to_account
  include Cache::Memcache::Group
  include Redis::RedisKeys
  include Redis::OthersRedis
  include BusinessCalendarExt::Association

  after_commit :clear_cache
  after_commit  :create_round_robin_list, on: :create, :if => :round_robin_enabled?
  after_commit  :update_round_robin_list, on: :update
  after_commit  :delete_round_robin_list, on: :destroy
  before_save :create_model_changes

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id
  
   has_many :agent_groups , :class_name => "AgentGroup", :foreign_key => "group_id", :dependent => :destroy
   
   has_many :agents, :through => :agent_groups, :source => :user , :conditions => ["users.deleted=?", false]

   has_many :tickets, :class_name => 'Helpdesk::Ticket', :dependent => :nullify
   has_many :email_configs, :dependent => :nullify
   
   belongs_to :escalate , :class_name => "User", :foreign_key => "escalate_to"
   belongs_to :business_calendar
   
   has_and_belongs_to_many :accesses, 
    :class_name => 'Helpdesk::Access',
    :join_table => 'group_accesses',
    :insert_sql => proc { |record|
      %{
        INSERT INTO group_accesses (account_id, group_id, access_id) VALUES
        ("#{self.account_id}", "#{self.id}", "#{ActiveRecord::Base.sanitize(record.id)}")
     }
    }
    
   attr_accessible :name,:description,:email_on_assign,:escalate_to,:assign_time ,:import_id, 
                   :ticket_assign_type, :business_calendar_id,
                   :added_list, :removed_list, :agent_groups_attributes
   
   accepts_nested_attributes_for :agent_groups
   scope :active_groups_in_account, lambda { |account_id|
     { :joins => "inner join agent_groups on agent_groups.account_id = #{account_id} and
                   agent_groups.group_id = groups.id and groups.account_id = #{account_id}
                   inner join users ON agent_groups.account_id = #{account_id} and
                   agent_groups.user_id = users.id and users.account_id = #{account_id}
                   and users.helpdesk_agent = 1 and users.deleted = 0",
       :group => "agent_groups.group_id" }
    }
   liquid_methods :name

   scope :round_robin_groups, :conditions => { :ticket_assign_type => true}

  API_OPTIONS = {
    :except  => [:account_id,:email_on_assign,:import_id],
    :include => { 
      :agents => {
        :only => [:id,:name,:email,:created_at,:updated_at,:active,:customer_id,:job_title,
                  :phone,:mobile,:twitter_id, :description,:time_zone,:deleted,
                  :helpdesk_agent,:fb_profile_id,:external_id,:language,:address],
        :methods => [:company_id] 
      }
    }
  }
    
  ASSIGNTIME = [
    [ :half,    I18n.t("group.assigntime.half"),      1800 ], 
    [ :one,     I18n.t("group.assigntime.one"),       3600 ], 
    [ :two,     I18n.t("group.assigntime.two"),       7200 ], 
    [ :four,    I18n.t("group.assigntime.four"),      14400 ], 
    [ :eight,   I18n.t("group.assigntime.eight"),     28800 ], 
    [ :twelve,  I18n.t("group.assigntime.twelve"),    43200 ], 
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

  def to_xml(options = {})
    options.merge!(API_OPTIONS)
    super(options)
  end

  def as_json(options = {})
    options.merge!(API_OPTIONS)
    super options
  end

  def next_available_agent
    return nil unless round_robin_enabled?


    current_agent_id = get_others_redis_rpoplpush(round_robin_key, round_robin_key)
    return account.agents.find_by_user_id(current_agent_id)

    #COMMENTING THE BELOW CODE to avoid complex logix . If required, we ll put back again.
    # repetition_list = Set.new
    # available_agent = nil
    # break_condition = false

    # until break_condition do
    #   current_agent_id  = get_others_redis_rpoplpush(round_robin_key, round_robin_key)

    #   break if current_agent_id.blank? #Empty list

    #   agent = account.agents.find_by_user_id(current_agent_id)
    #   available_agent = agent if agent and agent.available?
    #   break_condition = true if (repetition_list.include?(current_agent_id) or available_agent)

    #   repetition_list << current_agent_id #unless repetition_list.include?(current_agent_id)
    # end
    
  end

  def round_robin_enabled?
    (ticket_assign_type == TICKET_ASSIGN_TYPE[:round_robin]) and self.account.features_included?(:round_robin)
  end

  def round_robin_queue
    get_others_redis_list(round_robin_key)
  end

  def remove_agent_from_round_robin(user_id)
    delete_agent_from_round_robin(user_id) 
  end

  def round_robin_key
    GROUP_ROUND_ROBIN_AGENTS % { :account_id => self.account_id, 
                               :group_id => self.id}
  end

  def add_or_remove_agent(user_id, add=true)
    newrelic_begin_rescue {
      $redis_others.multi do 
        $redis_others.lrem(round_robin_key,0,user_id)
        $redis_others.lpush(round_robin_key,user_id) if add
      end
    }
  end

  private

  def create_round_robin_list
    user_ids = self.agent_groups.available_agents.map(&:user_id)
    set_others_redis_lpush(round_robin_key, user_ids) if user_ids.any?
  end

  def update_round_robin_list
    return unless @model_changes.key?(:ticket_assign_type)
    round_robin_enabled? ? create_round_robin_list : delete_round_robin_list
  end

  def delete_round_robin_list
    remove_others_redis_key(round_robin_key)
  end 

  def delete_agent_from_round_robin(user_id) #new key
      get_others_redis_lrem(round_robin_key, user_id)
  end

  def create_model_changes
    @model_changes = self.changes.to_hash
    @model_changes.symbolize_keys!
  end 
  
end
