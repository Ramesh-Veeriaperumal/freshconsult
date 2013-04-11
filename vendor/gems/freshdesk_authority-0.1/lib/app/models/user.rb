class User < ActiveRecord::Base
  
  include Authority::Rails::ModelHelpers
  
  belongs_to :account
  has_many :projects
  has_many :roles
  
  def privilege_list=(privilege_array)
    self.privileges = User.privileges_mask(privilege_array).to_s
  end
  
  # should i move this into model helpers?
  # will be used only in roles
  # as of not its a self.privileges_mask inside helpkit
  def self.privileges_mask(privilege_array)
    (privilege_array & PRIVILEGES_BY_NAME).map { |r| 2**PRIVILEGES[r] }.sum
  end
end