module ErrorHandlingMethods

	def render_404
     # NewRelic::Agent.notice_error(ActionController::RoutingError,{:uri => request.url,
     #                                                              :referer => request.referer,
     #                                                              :request_params => params})
		respond_to do |format|
			http_code = Error::HttpErrorCode::HTTP_CODE[:not_found] 
		    result = "Record Not Found"
		    format.any(:xml, :json) { 
		      api_responder({:message => result, :http_code => http_code, :error_code => "Not Found"})
		    }
			format.html {
				render :file => "#{Rails.root}/public/404.html", :status => :not_found
			}
		    
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
		result = "Request Failed"
		http_code = Error::HttpErrorCode::HTTP_CODE[:bad_request]
		respond_to do |format|
			format.any(:xml, :json) {
			 api_responder({:message=>result, :http_code => http_code, :error_code => "Bad Request"})
			}
		end
  	end

  	def handle_error (error)
		Rails.logger.debug "API::Error  =>" + error.message
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
 					render :xml => error_hash.to_xml(:root => :error_details, :skip_instruct => true, :dasherize => false),:status => error_hash[:http_code]
 				else
 					render :xml => error_hash[:errors], :status => error_hash[:http_code]
 				end
 			}
 			format.json {
 				if params[:error] == "new"
 					render :json => {:error_details => error_hash}, :status => error_hash[:http_code]
 				else
 					render :json =>  error_hash[:errors], :status => error_hash[:http_code]
 				end
 			}
 		end
  	end
end