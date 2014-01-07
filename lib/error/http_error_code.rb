module Error::HttpErrorCode

	CODES=[
			[:bad_request, 400, "Request failed"],
			[:authorization_required, 401, "Authentication failure"],
			[:forbidden, 403, "Access denied"],
			[:not_found, 404 , "Record not found"],
			[:method_not_allowed, 405 , "Method not allowed"],
			[:unprocessable_entity, 422, "Validation error"],
			[:too_many_requests, 429,"Exceeds the maximum number of api calls"]
		  ]

	CODE_OPTIONS = CODES.map { |i| [i[1], i[2]] }
	HTTP_CODE = Hash[*CODES.map { |i| [i[0], i[1]] }.flatten]
	CUSTOM_MESSAGE = Hash[*CODES.map { |i| [i[0], i[2]] }.flatten]	
end