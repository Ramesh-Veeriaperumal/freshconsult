module ErrorHelper

    def format_error(errors)
   		@errors = []	
   		errors.each do |attribute, value|
     		@errors << ::ApiError::BadRequestError.new(attribute,value)
        end
    end

    def find_http_error_code(errors) # returns most frequent error in an array
    	errors.collect(&:http_code).group_by{|i| i}.max{|x,y| x[1].length <=> y[1].length}[0]
    end
  
end