class Workers::Community::BulkSpam
  extend Resque::AroundPerform

  @queue = 'bulk_spam'

  class << self

  	include SpamAttachmentMethods
  	include SpamPostMethods

  	def perform(params)

  		Account.current.topics.find(:all, 
                                  :conditions => { :id => params[:topic_ids] }, 
                                  :include => :posts
                                  ).each do |topic|
  			if create_dynamo_post(topic.posts.first)
	  			topic.destroy 
	  			report_post(@spam)
	  		end
  		end	
  	end

	end
end