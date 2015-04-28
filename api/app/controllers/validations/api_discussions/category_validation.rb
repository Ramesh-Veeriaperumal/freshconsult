module ApiDiscussions
	class CategoryValidation
    include ActiveModel::Validations 

    attr_accessor :name, :description
    validates_presence_of :name  

    def initialize(params={})
      @name  = params["name"]
      @description = params["description"]
    end
 	end
end