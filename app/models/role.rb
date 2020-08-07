class Role < ActiveRecord::Base
  self.primary_key = :id
  
  include Authority::FreshdeskRails::ModelHelpers
  include Chat::Constants
  include MemcacheKeys

  before_destroy :destroy_user_privileges
  after_commit :update_user_privileges, on: :update
  before_create :set_or_remove_company_privilege
  before_update :set_or_remove_company_privilege

# uncomment for chat privileges phase 2
  # after_commit  ->(obj) { obj.update_liveChat_role } , on: :create
  # after_commit  ->(obj) { obj.update_liveChat_role } , on: :update
  # after_commit  :destroy_liveChat_role , on: :destroy

  #Acutal recalculationg of privilege masks part should be
  #moved to background processing.
  
  belongs_to_account

  has_many :user_roles, class_name: 'UserRole'
  has_many :users, through: :user_roles, class_name: 'User', autosave: true

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id

  attr_accessible :name, :description

  #Role-Based scopes
  scope :default_roles, -> { where(default_role: true) }
  scope :custom_roles,  -> { where(default_role: false) }
  scope :account_admin, -> { where(name: 'Account Administrator') }
  scope :admin,         -> { where(name: 'Administrator') }
  scope :supervisor,    -> { where(name: 'Supervisor') }
  scope :agent,         -> { where(name: 'Agent') }
  scope :field_agent,   -> { where(name: 'Field technician') }
  scope :coach,         -> { where(name: 'Coach') }
  
  API_OPTIONS = { 
    :except     => [:account_id, :privileges]
  } 

  attr_protected :privileges 

  MA_ROLES_TO_BE_UPDATED = ["Supervisor", "Administrator", "Account Administrator"]

  after_commit :clear_cache

  def privilege_list=(privilege_data)
    privilege_data = privilege_data.collect {|p| p.to_sym unless p.blank?}.compact
    # Remove this check once new privileges list shown in UI
    unless self.default_role
      Helpdesk::PrivilegesMap::MIGRATION_MAP.each do |key,value|
          privilege_data.concat(value) if privilege_data.include?(key)
      end
    end
    self.privileges = Role.privileges_mask(privilege_data.uniq).to_s
  end

  def privilege_list
      privileges = []
      PRIVILEGES_BY_NAME.each do |privilege|
        privileges.push(privilege) if self.privilege?(privilege)
      end
      privileges
  end

  def self.privileges_mask(privilege_data)
    (privilege_data & PRIVILEGES_BY_NAME).map { |r| 2**PRIVILEGES[r] }.sum
  end

  def as_json(options={})
    options.merge!(API_OPTIONS)
    #(options[:methods] ||= []).push(:system_role)
    super options
  end

  def to_xml(options={})
    options.merge!(API_OPTIONS)
    #(options[:methods] ||= []).push(:system_role)
    super options
  end

  def chat_privileges
    CHAT_PRIVILEGES & self.privilege_list
  end

  def system_role
    self.default_role
  end

  def custom_role?
    !self.default_role
  end

  def self.add_manage_availability_privilege(account = Account.current)
    success = true
    account.roles.each do |role|
      next if !(!role.privilege?(:manage_availability) and ((role.custom_role? and role.privilege?(:admin_tasks)) or MA_ROLES_TO_BE_UPDATED.include?(role.name)))

      role.privilege_list = (role.abilities + role.manage_availability_privileges).flatten
      success = false unless role.save      
    end
    success
  end

  def self.remove_manage_availability_privilege(account = Account.current)
    success = true
    account.roles.each do |role|
      next if !role.privilege?(:manage_availability)

      role.privilege_list = (role.abilities - role.manage_availability_privileges).flatten
      success = false unless role.save    
    end
    success
  end

  def manage_availability_privileges
    view_admin_enabled = RoleConstants::PRIVILEGE_DEPENDENCY_MAP[:view_admin].any? {|privilege| privilege?(privilege)}
    view_admin_enabled ? [:manage_availability] : [:view_admin, :manage_availability]
  end
  # protected
  #
  #   def update_liveChat_role
  #     siteId = account.chat_setting.site_id
  #     chat_privileges_list = CHAT_PRIVILEGES & self.privilege_list
  #       LivechatWorker.perform_async({:worker_method => "create_role", :siteId => siteId,
  #                       :name => self.name, :default_role => self.default_role, :external_id => self.id,
  #                       :privilege_list => chat_privileges_list.map(&:to_s)})
  #   end
  #
  #   def destroy_liveChat_role(siteId = nil)
  #     siteId = siteId.nil? ? account.chat_setting.site_id : siteId
  #     if account.features?(:chat) && siteId
  #       LivechatWorker.perform_async({:worker_method => "delete_role", :siteId => siteId, :name=> self.name})
  #     end
  #   end

  def clear_cache
    key = ACCOUNT_ROLES % { account_id: self.account_id }
    MemcacheKeys.delete_from_cache key
  end

  private
    def destroy_user_privileges
      users.all.each do |user|
        roles = user.roles.reject { |r| r.id == self.id }
        privileges = union_privileges roles
        user.update_attribute(:privileges, privileges)
      end
    end
    
    def update_user_privileges
      Roles::UpdateUserPrivileges.perform_async({role_id: self.id, performed_by_id: User.current.id})
    end

    def set_or_remove_company_privilege
      return if account.launched?(:contact_company_split)

      if privilege?(:manage_contacts)
        self.privileges = (privileges.to_i | (1 << PRIVILEGES[:manage_companies])).to_s
      elsif privilege?(:manage_companies)
        self.privileges = (privileges.to_i & ~(1 << PRIVILEGES[:manage_companies])).to_s
      end

      if privilege?(:delete_contact)
        self.privileges = (privileges.to_i | (1 << PRIVILEGES[:delete_company])).to_s
      elsif privilege?(:delete_company)
        self.privileges = (privileges.to_i & ~(1 << PRIVILEGES[:delete_company])).to_s
      end
    end
end
