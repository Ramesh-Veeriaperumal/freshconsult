module ErrorHandlingMethods

	def render_404
     # NewRelic::Agent.notice_error(ActionController::RoutingError,{:uri => request.url,
     #                                                              :referer => request.referer,
     #        :request_params => params})
     	http_code = Error::HttpErrorCode::HTTP_CODE[:not_found] 
		result = "Record Not Found"                                                      
		request_format = request.url
		error_content = {:message => result, :http_code => http_code, :error_code => "Not Found"}
		if request_format.include? ".xml" 
			render :xml => error_content.to_xml(:root => :error_details, :skip_instruct => true, :dasherize => false),:status => http_code
		elsif request_format.include? ".json" 
			render :json => {:error_details => error_content}, :status => http_code
		else
			render :file => "#{Rails.root}/public/404.html", :status => :not_found
		end
  	end

  
  	def record_not_found (exception)
		Rails.logger.debug "Error  =>" + exception.message
		respond_to do |format|
		  format.html {
		    unless @current_account
		      render("/errors/invalid_domain")
		    else
		      render_404
		    end
		  }
		    http_code = Error::HttpErrorCode::HTTP_CODE[:not_found] 
		    result = "Record Not Found"
		    format.any(:xml, :json) { 
		      api_responder({:message => result, :http_code => http_code, :error_code => "Not Found"})
		    }
	    end
	end

  	def MethodNotAllowed(exception)
		Rails.logger.debug "Error  =>" + exception.message
		result = "Request Failed"
		http_code = Error::HttpErrorCode::HTTP_CODE[:method_not_allowed]
		respond_to do |format|
		    format.any(:xml, :json) {
		      api_responder({:message=>result, :http_code => http_code, :error_code => "Method not allowed"})
		    }
	    end
	end

  	def generic_error(exception)
		Rails.logger.debug "Error msg =>" + exception.message
		Rails.logger.debug "Stack trace =>" + exception.backtrace.join("\n")
		http_code = Error::HttpErrorCode::HTTP_CODE[:bad_request]
		result = "Request Failed"
		respond_to do |format|
			format.any(:xml, :json) {
				params[:error] = "new"
				api_responder({:message=>result, :http_code => http_code, :error_code => "Bad Request"})
			}
		end
  	end

  	def handle_error (error)
		Rails.logger.debug "API::Error  =>" + error.message
		Rails.logger.debug "Stack trace =>" + exception.backtrace.join("\n")
		respond_to do | format|
			result = error.message
			http_code = Error::HttpErrorCode::HTTP_CODE[:bad_request]
			format.any(:xml, :json)  { api_responder({:message => result, :http_code => http_code, :error_code => "Bad Request"})  and return }
		end
  	end

  	def api_responder(error_hash)
 		respond_to do |format|
 			format.xml {
 				if params[:error] == "new" 
 					render :xml => error_hash.to_xml(:root => :error_details, :skip_instruct => true, :dasherize => false),:status => error_hash[:http_code] and return
 				elsif error_hash[:message] == "Record Not Found"
 					render :xml =>{:error=> error_hash[:message]}.to_xml(:indent =>2,:root=> :errors),:status =>error_hash[:http_code] and return
 				else
 					render :xml => error_hash[:errors], :status => error_hash[:http_code] and return
 				end
 			}
 			format.json {
 				if params[:error] == "new" 
 					render :json => {:error_details => error_hash}, :status => error_hash[:http_code] and return
 				elsif error_hash[:message] == "Record Not Found"
 					render :json => {:errors =>{:error => error_hash[:message]}}.to_json,:status => error_hash[:http_code] and return
 				else	
 					render :json =>  error_hash[:errors], :status => error_hash[:http_code] and return
 				end
 			}
 		end
  	end
end