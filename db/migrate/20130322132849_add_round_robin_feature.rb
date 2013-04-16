class AddRoundRobinFeature < ActiveRecord::Migration
  def self.up
    execute("insert into features (type, account_id, created_at, updated_at) select 'RoundRobinFeature', account_id, now(), now() from features where type='EstateFeature'")
  end

  def self.down
    execute("delete from features where type= 'RoundRobinFeature'")
  end
end
