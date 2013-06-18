class PopulateSuspendedStateToSubscriptions < ActiveRecord::Migration
  shard :none
  def self.up
  	execute <<-SQL
      UPDATE subscriptions SET state = "suspended" WHERE next_renewal_at < DATE(NOW() - INTERVAL 5 DAY)
    SQL
  end

  def self.down
  end
end
