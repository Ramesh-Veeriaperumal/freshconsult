class PopulateStateInTwitterHandle < ActiveRecord::Migration
  def self.up
    Lhm.change_table :social_twitter_handles, :atomic_switch => true do |m|
       m.ddl("ALTER TABLE %s MODIFY state int(11) DEFAULT 1" % m.name)
    end
    execute <<-SQL
      UPDATE social_twitter_handles SET state = 1 WHERE state IS NULL
    SQL
  end

  def self.down
    Lhm.change_table :social_twitter_handles, :atomic_switch => true do |m|
       m.ddl("ALTER TABLE %s MODIFY state int(11) DEFAULT NULL" % m.name)
    end
  end
end
