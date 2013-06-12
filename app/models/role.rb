class Role < ActiveRecord::Base
  
  include Authority::Rails::ModelHelpers

  belongs_to_account
  has_and_belongs_to_many :users, :join_table => "user_roles", :autosave => true
  
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
end