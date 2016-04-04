class PopulateStampTypeForForums < ActiveRecord::Migration
	shard :all
	
  def self.up
  	Sharding.run_on_all_shards do
		Account.active_accounts.find_in_batches(:batch_size => 200) do |accounts|
	  		accounts.each do |account|
		  		# Set stamp_type as unanswered for all topics under Questions Forum.
		  		execute("UPDATE topics SET stamp_type = #{Topic::QUESTIONS_STAMPS_BY_TOKEN[:unanswered]}  WHERE (forum_id IN (SELECT id FROM forums WHERE forum_type = #{Forum::TYPE_KEYS_BY_TOKEN[:howto]} AND account_id = #{account.id} )) AND account_id = #{account.id}")
		  		# Set stamp_type as answered for all topics under Questions Forum which has atleast one post marked as answer. 
		  		execute("UPDATE topics SET stamp_type = #{Topic::QUESTIONS_STAMPS_BY_TOKEN[:answered]}  WHERE (id IN (SELECT DISTINCT topic_id FROM posts WHERE answer = 1 AND account_id = #{account.id} )) AND account_id = #{account.id}")
		  		# Set stamp_type as unsolved for all topics under Problems Forum.
		  		execute("UPDATE topics SET stamp_type = #{Topic::PROBLEMS_STAMPS_BY_TOKEN[:unsolved]}  WHERE (forum_id IN (SELECT id FROM forums WHERE forum_type = #{Forum::TYPE_KEYS_BY_TOKEN[:problem]} AND account_id = #{account.id} )) AND account_id=#{account.id}")
		  	end
		end
  	end
  end

  def self.down
  	
	end
end
