#This is a temporary thing. As the user - role association is going to be one-one for sometime,
#have moved the role_token from Helpdesk::Authorization to User itself.
#Definitely need to revisit sometime later. by Shan

class AddRoleTokenToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :role_token, :string
  end

  def self.down
    remove_column :users, :role_token
  end
end
