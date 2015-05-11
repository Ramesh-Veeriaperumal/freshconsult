module ErrorHelper

    def format_error(errors, meta = nil)
   		formatted_errors = []	
   		errors.each do |attribute, value|
     		formatted_errors << ::ApiError::BadRequestError.new(attribute,value, get_params_if_any(attribute, meta))
        end
        formatted_errors
    end

    def find_http_error_code(errors) # returns most frequent error in an array
    	errors.collect(&:http_code).group_by{|i| i}.max{|x,y| x[1].length <=> y[1].length}[0]
    end
  
	def get_params_if_any(attribute, meta)
		 {:list => ApiConstants::LIST_FIELDS[attribute],
      		:meta => meta}
	end
end