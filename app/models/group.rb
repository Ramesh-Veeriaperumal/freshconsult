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
  include DataVersioning::Model
  include GroupConstants

  concerned_with :round_robin_methods, :skill_based_round_robin, :presenter, :constants

  publishable on: [:create, :update, :destroy]
  
  before_save :reset_toggle_availability, :create_model_changes
  before_save :set_default_type_if_needed, on: [:create]
  before_destroy :backup_user_ids, :save_deleted_group_info
  validate :agent_id_validation, :auto_ticket_assign_validation, if: -> {Account.current.field_service_management_enabled?}

  after_commit :round_robin_actions, :clear_cache
  after_commit :nullify_tickets, :destroy_group_in_liveChat, on: :destroy
  after_commit :sync_sbrr_queues

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id, :case_sensitive => false

  has_many :agent_groups,
           class_name: 'AgentGroup',
           foreign_key: 'group_id',
           after_add: :touch_agent_group_change,
           after_remove: :touch_agent_group_change

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
                  :capping_limit, :group_type

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
  scope :basic_round_robin_enabled, :conditions => ["ticket_assign_type = 1 and capping_limit = 0"], :order => :name
  scope :capping_enabled_groups, :conditions => ["ticket_assign_type = 1 and capping_limit > 0"], :order => :name
  scope :skill_based_round_robin_enabled, :order => :name,
        :conditions => ["ticket_assign_type = #{Group::TICKET_ASSIGN_TYPE[:skill_based]}"]
  scope :ocr_enabled_groups,
        order: :name,
        conditions: ["ticket_assign_type IN (?)", OMNI_CHANNEL_ASSIGNMENT_TYPES]
  
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
      multiple_agents_added = add_user_ids.count > 1
      add_user_ids.map { |user_id|
        agent_groups_array << build_agent_groups_hash(user_id).merge(:multiple_agents_added_to_group => multiple_agents_added)
      }
    end
    self.agent_groups_attributes = agent_groups_array if agent_groups_array.present?
  end

  def build_agent_groups_hash(user_id, id = nil)
    {:id => id, :user_id => user_id, :_destroy => id.present?}
  end

  def available_agents #fires 2 queries everytime
    user_ids = agent_groups.available_agents.map(&:user_id)
    account.users.find_all_by_id(user_ids)
  end

  def has_agent? agent
    agents.exists?('users.id' => agent.id)
  end

  def turn_off_automatic_ticket_assignment
      self.ticket_assign_type = TICKET_ASSIGN_TYPE[:default]
      self.capping_limit= 0
      self.save
  end

  def field_group? 
    self.group_type == GroupType.group_type_id(GroupConstants::FIELD_GROUP_NAME)  
  end

  def support_agent_group?
    group_type == Admin::AdvancedTicketing::FieldServiceManagement::Constant::SUPPORT_GROUP_TYPE
  end

  def automatic_ticket_assignment_enabled?
    AUTOMATIC_TICKET_ASSIGNMENT_TYPES.include?(ticket_assign_type)
  end

  def omni_channel_routing_enabled?
    OMNI_CHANNEL_ASSIGNMENT_TYPES.include?(ticket_assign_type)
  end

  private

  def save_deleted_group_info
    @deleted_model_info = as_api_response(:central_publish_destroy)
  end

    def self.api_filter(group_filter)
      {
        'field_agent_group': {
          conditions: { group_type: group_filter.group_type }
        },
        'support_agent_group': {
          conditions: { group_type: group_filter.group_type }
        }
      }
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

    def touch_agent_group_change(agent_group)
      agent_info = { id: agent_group.user_id, name: agent_group.user.name }
      Thread.current[:agent_changes].present? ? 
        Thread.current[:agent_changes].push(agent_info) : 
        Thread.current[:agent_changes]=[agent_info]
    end

    def set_default_type_if_needed
      self.group_type = GroupType.group_type_id(SUPPORT_GROUP_NAME) unless self.group_type
    end

    def agent_id_validation
      @group_type = GroupType.group_type_name(self.group_type)
      type = GROUPS_AGENTS_MAPPING[@group_type]
      user_ids = self.agent_groups.map(&:user_id)
      agents = Account.current.agents_from_cache
      group_agent_type = AgentType.agent_type_id(type)
      invalid_update = agents.any? { |x| x.agent_type != group_agent_type && user_ids.include?(x.user_id) }

      if invalid_update
        self.errors.add(:agent_groups, 'invalid_agent_ids') 
        return false
      end
      true
    end

    def auto_ticket_assign_validation
      if @group_type == FIELD_GROUP_NAME && !self.ticket_assign_type.eql?(TICKET_ASSIGN_TYPE[:default])
        self.errors.add(:ticket_assign_type, 'invalid_field_auto_assign') 
        return false
      end
      true
    end
  end