class UserRole < ActiveRecord::Base
  belongs_to_account
  
  belongs_to :user
  belongs_to :role, :class_name => 'Admin::Role'
end
