class PopulateAccountIdVotes < ActiveRecord::Migration
  def self.up
  	execute <<-SQL
			UPDATE votes INNER JOIN users ON votes.user_id = users.id 
			SET votes.account_id = users.account_id
  	SQL
  end

  def self.down
  	execute <<-SQL
			UPDATE votes SET account_id = NULL
  	SQL
  end
end
