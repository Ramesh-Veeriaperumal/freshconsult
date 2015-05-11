module ApiDiscussions
	class CategoryValidation
    include ActiveModel::Validations 

    attr_accessor :name
    validates_presence_of :name  

    def initialize(controller_params, item)
      @name = controller_params["name"] || item.try(:name)
    end
 	end
end