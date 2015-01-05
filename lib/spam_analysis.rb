class SpamAnalysis

	def self.push post, additional_info = {}
		begin
			$sqs_spam_analysis.send_message(post_json(post,additional_info))
		rescue Exception => e
			Rails.logger.error("Error occurred while pushing data to sqs spam analysis queue!! \n#{e.message}\n#{e.backtrace.join("\n")}")
		end
	end

	def self.post_json post, additional_info
		case post.class
		when Post
			post_json = post.to_json(:include => {:user => { :only => [:id, :name, :email, 
																	:fb_profile_id, :twitter_id]}})
			post_hash = JSON.parse(post_json)
			post_hash["post"].merge!(additional_info)
		else
			post_hash = { "post" => post.attributes.merge!(additional_info) }
		end
		post_json = post_hash.to_json
	end	
end