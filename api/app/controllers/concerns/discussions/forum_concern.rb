module Discussions::ForumConcern
  extend ActiveSupport::Concern

    included do
       # Needed for removing es index for topic. Shouldn't be part of topic model. Performance constraints to enqueue jobs for each topic
       before_filter :back_up_topic_ids, :only => [:destroy]
       before_filter :assign_forum_category_id, :only => [:update]
    end

    protected
  
    def back_up_topic_ids
       @forum.backup_forum_topic_ids  
    end  

    def scoper
  	   current_account.forums
  	end

    def set_customer_forum_params 
      customers = params[:customers] || params[cname]["customers"]
      params[cname][:customer_forums_attributes] = {}
      params[cname][:customer_forums_attributes][:customer_id] = (customers ? customers.split(',') : [])
    end

    def assign_forum_category_id
      @forum.forum_category_id = params[cname][:forum_category_id] if params[cname][:forum_category_id]
    end

    private
end
