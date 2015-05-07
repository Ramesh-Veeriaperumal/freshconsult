module ApiDiscussions
	class TopicValidation
    include ActiveModel::Validations 

    attr_accessor :title, :forum_id, 
    validates_presence_of :forum_id, :title
  
    def initialize(controller_params, item)
      @title = controller_params["title"] || item.forum_id
      @forum_id = controller_params["forum_id"] ? controller_params["forum_category_id"].to_i : item.forum_ids
    end
    
 	end
end