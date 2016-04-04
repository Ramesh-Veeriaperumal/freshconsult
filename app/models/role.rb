class Role < ActiveRecord::Base
  self.primary_key = :id
  
  include Authority::FreshdeskRails::ModelHelpers
  before_destroy :destroy_user_privileges
  after_update :update_user_privileges

  #Acutal recalculationg of privilege masks part should be
  #moved to background processing.
  
  belongs_to_account
  has_and_belongs_to_many :users, :join_table => "user_roles", :autosave => true
  
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id

  #Role-Based scopes
  scope :default_roles, -> { where(:default_role => true) }
  scope :account_admin, -> { where(:name => 'Account Administrator') }
  scope :admin,         -> { where(:name => 'Administrator') }
  scope :supervisor,    -> { where(:name => 'Supervisor') }
  scope :agent,         -> { where(:name => 'Agent') }
  
  API_OPTIONS = { 
    :except     => [:account_id, :privileges]
  } 

  attr_protected :privileges 

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

  def system_role
    self.default_role
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
      users.all.each do |user|
        privileges = (union_privileges user.roles).to_s
        user.update_attribute(:privileges, privileges)
      end 
    end
end
