class Role < ActiveRecord::Base
  
  # FIXME: Prompt if users are associated with role during delete ?
  # FIXME: valid if we stick to account_admin flag
    # FIXME: a role with which account_admin is associated is deleted
    # FIXME: user is changed to a role without manage_account
  
  include Authority::ModelHelpers
  before_destroy :destroy_user_privileges
  after_save :update_user_privileges

  #Acutal recalculationg of privilege masks part should be
  #moved to background processing.
  
  belongs_to_account
  has_many :user_roles, :dependent => :destroy
  has_many :users, :through => :user_roles

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id
  
  attr_protected :privileges 

  def privilege_list=(privilege_data)
    privilege_data = privilege_data.collect {|p| p.to_sym unless p.blank?}.compact
    self.privileges = Role.privileges_mask(privilege_data).to_s
  end

  def self.privileges_mask(privilege_data)
    (privilege_data & PRIVILEGES_BY_NAME).map { |r| 2**PRIVILEGES[r] }.sum
  end

  private
    def destroy_user_privileges
      users.each do |user|
        roles = user.roles.reject { |r| r.id == self.id }
        privileges = union_privileges roles
        user.update_attribute(:privileges, privileges)
      end
    end
    
    def update_user_privileges
      users.each do |user|
        privileges = (union_privileges user.roles).to_s
        user.update_attribute(:privileges, privileges)
      end 
    end
end
