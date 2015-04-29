module ApiDiscussions
	class CategoryValidation
    include ActiveModel::Validations 

    attr_accessor :name
    validates_presence_of :name  

    def initialize(params, cname, item)
      @name = params[cname]["name"] || item.name
    end
 	end
end