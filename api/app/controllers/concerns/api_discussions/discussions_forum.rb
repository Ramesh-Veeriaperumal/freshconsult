module ApiDiscussions::DiscussionsForum
  extend ActiveSupport::Concern

    included do
       # Needed for removing es index for topic. Shouldn't be part of topic model. Performance constraint to enqueue jobs for rach topic
       before_filter :back_up_topic_ids, :only => [:destroy]
       before_filter :set_customer_forum_params, :only => [:create, :update]
    end

    protected
  
    def back_up_topic_ids
       @forum.backup_forum_topic_ids  
    end  

    def scoper
  	   current_account.forums
  	end

    def set_customer_forum_params 
      params[cname][:customer_forums_attributes] = {}
      params[cname][:customer_forums_attributes][:customer_id] = (params[:customers] ? params[:customers].split(',') : [])
    end

    private
end
