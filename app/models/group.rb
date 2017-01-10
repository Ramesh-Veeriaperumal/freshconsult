class Group < ActiveRecord::Base
  self.primary_key = :id
  
  xss_sanitize  :only => [:name, :description], :plain_sanitizer => [:name, :description]
  belongs_to_account
  include Cache::Memcache::Group
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Redis::RoundRobinRedis
  include BusinessCalendarExt::Association
  include AccountOverrider
  include RoundRobinCapping::Methods

  TICKET_ASSIGN_TYPE = {:default => 0, :round_robin => 1, :skill_based => 2} #move other constants after merge - hari

  concerned_with :round_robin_methods
  
  before_save :reset_toggle_availability, :create_model_changes
  before_destroy :backup_user_ids

  after_commit :round_robin_actions, :clear_cache
  after_commit :nullify_tickets, :destroy_group_in_liveChat, on: :destroy
  after_commit :sync_sbrr_queues

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id

  has_many :agent_groups , :class_name => "AgentGroup", :foreign_key => "group_id"
  has_many :agents, :through => :agent_groups, :source => :user, :order => :name,
            :conditions => ["users.deleted=?", false], :dependent => :destroy

  has_many :tickets, :class_name => 'Helpdesk::Ticket'
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

  has_many :status_groups, :foreign_key => "group_id", :dependent => :destroy

  has_many :freshfone_number_groups, :class_name => "Freshfone::NumberGroup",
            :foreign_key => "group_id", :dependent => :delete_all

  has_many   :ecommerce_accounts, :class_name => 'Ecommerce::Account', :dependent => :nullify

  attr_accessible :name,:description,:email_on_assign,:escalate_to,:assign_time ,:import_id, 
                   :ticket_assign_type, :toggle_availability, :business_calendar_id, :agent_groups_attributes,
                   :capping_limit

  attr_accessor :capping_enabled

  accepts_nested_attributes_for :agent_groups, :allow_destroy => true

  scope :active_groups_in_account, lambda { |account_id|
      sanitize_joins = sanitize_sql_array(["inner join agent_groups on agent_groups.account_id = :account_id and
                   agent_groups.group_id = groups.id and groups.account_id = :account_id
                   inner join users ON agent_groups.account_id = :account_id and
                   agent_groups.user_id = users.id and users.account_id = :account_id
                   and users.helpdesk_agent = 1 and users.deleted = 0", :account_id => account_id])
      { :joins => sanitize_joins,
       :group => "agent_groups.group_id" }
    }
  liquid_methods :name

  scope :trimmed, :select => [:'groups.id', :'groups.name']
  scope :disallowing_toggle_availability, :conditions => { :toggle_availability => false }
  scope :round_robin_groups, :conditions => 'ticket_assign_type > 0', :order => :name
  scope :capping_enabled_groups, :conditions => ["ticket_assign_type = 1 and capping_limit > 0"], :order => :name
  scope :skill_based_round_robin_enabled, :order => :name,
        :conditions => ["ticket_assign_type = #{Group::TICKET_ASSIGN_TYPE[:skill_based]}"]

  API_OPTIONS = {
    :except  => [:account_id,:email_on_assign,:import_id],
    :include => { 
      :agents => {
        :only => [:id,:name,:email,:created_at,:updated_at,:active,:job_title,
                  :phone,:mobile,:twitter_id, :description,:time_zone,:deleted,
                  :helpdesk_agent,:fb_profile_id,:external_id,:language,:address, :unique_external_id],
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

  TICKET_ASSIGN_OPTIONS = [
                            ['group_ticket_options.default',         '0'], 
                            ['group_ticket_options.round_robin',     '1'],
                            ['group_ticket_options.skill_based',     '2']
                          ]

  ASSIGNTIME_OPTIONS = ASSIGNTIME.map { |i| [i[1], i[2]] }
  ASSIGNTIME_NAMES_BY_KEY = Hash[*ASSIGNTIME.map { |i| [i[2], i[1]] }.flatten]
  ASSIGNTIME_KEYS_BY_TOKEN = Hash[*ASSIGNTIME.map { |i| [i[0], i[2]] }.flatten]
  MAX_CAPPING_LIMIT = 100
  CAPPING_LIMIT_OPTIONS = (2..MAX_CAPPING_LIMIT).map { |i| 
    ["#{i} #{I18n.t("group.capping_tickets")}", i] 
    }.insert(0, ["1 #{I18n.t("group.capping_ticket")}", 1])
  
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

  def build_agent_groups_attributes(agent_list)
    old_user_ids    = self.new_record? ? [] : self.agent_groups.pluck(:user_id)
    agent_list      = agent_list.split(',').map(&:to_i)
    add_user_ids    = Account.current.agents.where(:user_id => agent_list - old_user_ids).pluck(:user_id)
    delete_user_ids = old_user_ids - agent_list

    agent_groups_array = []
    if delete_user_ids.present?
      agent_groups.where(:user_id => delete_user_ids).map { |agent_group|
        agent_groups_array << build_agent_groups_hash(agent_group.user_id, agent_group.id)
      }
    end
    if add_user_ids.present?
      add_user_ids.map { |user_id|
        agent_groups_array << build_agent_groups_hash(user_id)
      }
    end
    self.agent_groups_attributes = agent_groups_array if agent_groups_array.present?
  end

  def build_agent_groups_hash(user_id, id = nil)
    {:id => id, :user_id => user_id, :_destroy => id.present?}
  end

  def skill_based_round_robin_enabled?
    ticket_assign_type == TICKET_ASSIGN_TYPE[:skill_based]
  end

  def available_agents #fires 2 queries everytime
    user_ids = agent_groups.available_agents.map(&:user_id)
    account.users.find_all_by_id(user_ids)
  end

  def ticket_queues
    @ticket_queues ||= SBRR::QueueAggregator::Ticket.new(nil, {:group => self}).relevant_queues
  end

  def has_agent? agent
    agents.exists?('users.id' => agent.id)
  end

  private

    def sync_sbrr_queues
      if account.skill_based_round_robin_enabled?
        if transaction_include_action?(:destroy)
          destroy_sbrr_queues if skill_based_round_robin_enabled?
          return
        end
        return if transaction_include_action?(:create) && !skill_based_round_robin_enabled?

        if skill_based_round_robin_toggled? 
          skill_based_round_robin_enabled? ?
            SBRR::Toggle::Group.perform_async(:group_id => self.id) : destroy_sbrr_queues
        elsif capping_limit_changed?
          SBRR::Toggle::Group.perform_async(:group_id => self.id, 
            :capping_limit_change => capping_limit_change)
        end
      end
    end

    def destroy_sbrr_queues #no group object in worker, just key deletion, one redis call
      keys = []
      
      [ticket_queues, user_queues].each do |queues|
        keys << queues.map do |queue|
          model_ids = queue.all
          lock_keys = model_ids.map{|model_id| queue.lock_key(model_id)}
          [queue.key, lock_keys]
        end
      end
      keys.flatten!

      del_round_robin_redis keys
    end

    def user_queues
      @user_queues ||= SBRR::QueueAggregator::User.new(nil, {:group => self}).relevant_queues
    end

    def capping_limit_change
      return false if !capping_limit_changed?
      ((capping_limit_changes[1] - capping_limit_changes[0]) > 0) ? :increased : :decreased
    end

    def capping_limit_changed?
      @model_changes.key?(:capping_limit)
    end

    def capping_limit_changes
      @model_changes[:capping_limit]
    end

    def create_model_changes
      @model_changes = self.changes.to_hash
      @model_changes.symbolize_keys!
    end

    def backup_user_ids
      @user_ids = agents.pluck(:user_id)
    end

    def destroy_group_in_liveChat
      siteId = account.chat_setting.site_id
      if account.features?(:chat) && siteId
        LivechatWorker.perform_async({:worker_method =>"delete_group",
                                            :siteId => siteId, :group_id => self.id})
      end
    end

    def nullify_tickets
      Helpdesk::ResetGroup.perform_async({:group_id => self.id, :reason => {:delete_group => [self.name]}})
    end

    def skill_based_round_robin_toggled?
      @model_changes.key?(:ticket_assign_type) && 
        @model_changes[:ticket_assign_type].any? do |_ticket_assign_type| 
          _ticket_assign_type == TICKET_ASSIGN_TYPE[:skill_based]
        end
    end

end
