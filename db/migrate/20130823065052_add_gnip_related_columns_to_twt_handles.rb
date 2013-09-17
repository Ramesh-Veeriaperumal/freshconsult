class AddGnipRelatedColumnsToTwtHandles < ActiveRecord::Migration
  shard :none
  def self.up
  	execute <<-SQL
  		ALTER TABLE social_twitter_handles ADD COLUMN (rule_value text, 
                                                     rule_tag text,
                                                     gnip_rule_state int DEFAULT 0)
  	SQL
  end

  def self.down
  	execute <<-SQL
  		ALTER TABLE social_twitter_handles DROP COLUMN rule_value,
                                         DROP COLUMN rule_tag,
                                         DROP COLUMN gnip_rule_state
  	SQL
  end
end
