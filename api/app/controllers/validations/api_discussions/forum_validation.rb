module ApiDiscussions
	class ForumValidation
    include ActiveModel::Validations 

    attr_accessor :name, :forum_category_id, :forum_type, :forum_visibility
    validates_presence_of :name, :forum_category_id
    validates_inclusion_of :forum_visibility, :in => Forum::VISIBILITY_KEYS_BY_TOKEN.values
    validates_inclusion_of :forum_type, :in => Forum::TYPE_KEYS_BY_TOKEN.values
  
    def initialize(controller_params, item)
      @name = controller_params["name"] || item.try(:name)
      @forum_category_id = controller_params["forum_category_id"].try(:to_i) || item.try(:forum_category_id)
      @forum_type = controller_params["forum_type"].try(:to_i) || item.try(:forum_type)
      @forum_visibility = controller_params["forum_visibility"].try(:to_i) || item.try(:forum_visibility)
    end
    
 	end
end