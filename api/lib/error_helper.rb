module ErrorHelper

    def format_error(errors)
   		@errors = []	
   		errors.each do |attribute, value|
     		@errors << ::ApiError::BadRequestError.new(attribute,value)
        end
    end

    def find_http_error_code(errors)
    	errors.max_by(&:http_code).http_code.to_i
    end
  
end