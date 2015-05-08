module ApiDiscussions
	class ForumValidation
    include ActiveModel::Validations 

    attr_accessor :name, :forum_category_id, :forum_type, :forum_visibility
    validates :name, :forum_category_id, :presence => true
    validates :forum_category_id, :numericality => true
    validates :forum_visibility, inclusion: { in: Forum::VISIBILITY_KEYS_BY_TOKEN.values }
    validates :forum_type, inclusion: { in: Forum::TYPE_KEYS_BY_TOKEN.values }
  
    def initialize(controller_params, item)
      @name = controller_params["name"] || item.try(:name)
      @forum_category_id = controller_params["forum_category_id"].try(:to_i) || item.try(:forum_category_id)
      @forum_type = controller_params["forum_type"].try(:to_i) || item.try(:forum_type)
      @forum_visibility = controller_params["forum_visibility"].try(:to_i) || item.try(:forum_visibility)
    end
    
 	end
end