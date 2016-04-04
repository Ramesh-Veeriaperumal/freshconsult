class CleanupSupervisorRule < ActiveRecord::Migration
	shard :all
  def self.up
  	#Hours since first response due was looking at column first_response_time instead of frDueBy.
  	#Script to clean it up.
  	new_name = "frDueBy"
  	old_name = "first_response_time"
	Sharding.run_on_all_shards do 
		VaRule.find_in_batches(:batch_size => 300, 
			:conditions => ["rule_type = ? and filter_data like ?", 
			VAConfig::SUPERVISOR_RULE, "%#{old_name}%"]) do |rules|
			rules.each do |rule|
				changed = false
				rule.filter_data.each do |r|
					if r["name"] == old_name
						r["name"] = new_name
						changed = true
						puts "Changed rule: #{rule.id}, account id: #{rule.account_id}"
					end
				end
				rule.save if changed
			end
		end
	end
  end

  def self.down
  end
end
