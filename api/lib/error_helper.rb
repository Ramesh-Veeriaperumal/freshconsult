module ErrorHelper

    def format_error(errors)
   		formatted_errors = []	
   		errors.each do |attribute, value|
     		formatted_errors << ::ApiError::BadRequestError.new(attribute,value, get_list_if_any(attribute))
        end
        formatted_errors
    end

    def find_http_error_code(errors) # returns most frequent error in an array
    	errors.collect(&:http_code).group_by{|i| i}.max{|x,y| x[1].length <=> y[1].length}[0]
    end
  
	def get_list_if_any(attribute)
		 {:list => ApiConstants::LIST_FIELDS[attribute]}
	end
end