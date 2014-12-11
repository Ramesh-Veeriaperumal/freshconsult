class CreateCustomRolesFeature < ActiveRecord::Migration
  shard :none
  def self.up
    execute("INSERT INTO features (type, account_id, created_at, updated_at)
      SELECT 'CustomRolesFeature', account_id, now(), now()
      FROM features WHERE type = 'EstateFeature'")
     
    execute("INSERT INTO features (type, account_id, created_at, updated_at)
      SELECT 'CustomRolesFeature', account_id, now(), now()
      FROM features WHERE type = 'EstateClassicFeature'")
  end

  def self.down
    execute("DELETE FROM features WHERE type = 'CustomRolesFeature'")
  end
end
