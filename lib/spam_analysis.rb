class SpamAnalysis

	def self.push post, additional_info = {}
		begin
			post_json = post.to_json(:include => {:user => { :only => [:id, :name, :email, 
																	:fb_profile_id, :twitter_id]}})
			post_hash = JSON.parse(post_json)
			post_hash["post"].merge!(additional_info)
			post_json = post_hash.to_json
			$sqs_spam_analysis.send_message(post_json)
		rescue Exception => e
			Rails.logger.error("Error occurred while pushing data to sqs spam analysis queue!! \n#{e.message}\n#{e.backtrace.join("\n")}")
		end
	end
end