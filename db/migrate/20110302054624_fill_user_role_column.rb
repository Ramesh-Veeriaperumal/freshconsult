class FillUserRoleColumn < ActiveRecord::Migration
  def self.up
   execute  "update users set user_role = 1 where role_token = 'admin'"
   execute  "update users set user_role = 2 where role_token = 'poweruser'"
   execute  "update users set user_role = 3 where role_token = 'customer'"
  end

  def self.down
  execute  "update users set user_role = 0"
  end
end
