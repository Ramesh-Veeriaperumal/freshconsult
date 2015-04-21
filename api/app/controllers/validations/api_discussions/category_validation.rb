module ApiDiscussions
	class CategoryValidation
    include ActiveModel::Validations 

    attr_accessor :name, :description
    validates_presence_of :name  

    def initialize(params={})
      @name  = params["forum_category"]["name"]
      @description = params["forum_category"]["description"]
    end
 	end
end