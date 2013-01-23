class Admin::Role < ActiveRecord::Base
  include Authority::ModelHelpers
  before_destroy :destroy_user_privileges
  after_save :update_user_privileges

  #Acutal recalculationg of privilege masks part should be
  #moved to background processing.
  
  belongs_to_account
  has_many :user_roles, :dependent => :destroy
  has_many :users, :through => :user_roles

  validates_presence_of :name
  validates_uniqueness_of :name #what about scope?! :scope => :account_id

  def privilege_list=(privilege_data)
    privilege_data = privilege_data.collect {|p| p.to_sym unless p.blank?}.compact
    self.privileges = Admin::Role.privileges_mask(privilege_data).to_s
  end

  def self.privileges_mask(privilege_data)
    (privilege_data & PRIVILEGES_BY_NAME).map { |r| 2**PRIVILEGES[r] }.sum
  end

  private
    def destroy_user_privileges
      users.each do |user|
        roles = user.roles.reject { |r| r.id == self.id }
        privileges = union_privileges roles #!?!?!?
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
