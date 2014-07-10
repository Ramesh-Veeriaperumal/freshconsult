class VersionDetectionError < Exception; end

class Integrations::BatchbookVersionDetector 

  def detect_batchbook_version(inst_app)

    return true unless inst_app.configs[:inputs]['version'] == "auto"
  	
    domain = inst_app.configs[:inputs]['domain']
  	key = inst_app.configs[:inputs]['api_key']
  	hrp = HttpRequestProxy.new
  	
  	params = { :domain => domain, :ssl_enabled => true, :rest_url => "api/v1/people.json?auth_token=#{key}&email=thisWillNotExist@anyyywhere.com" }
  	requestParams = { :method => "get", :user_agent => "_" }
  	response = hrp.fetch_using_req_params(params, requestParams)
    Rails.logger.debug "BB2 (New) status: #{response[:status]}\n"

  	if [200, 401].include?(response[:status])
  		Rails.logger.debug "BB2 (New) status: #{response[:status]}\n"
      inst_app.configs[:inputs]['version'] = 'new'
  		return true
  	elsif response[:status] == 404
	  	params.merge!({ :rest_url => "service/people.json?email=thisWillNotExist@anyyywhere.com", :username => key, :password => 'x', :ssl_enabled => false })
	  	response = hrp.fetch_using_req_params(params, requestParams)
      Rails.logger.debug "BB classic status: #{response[:status]}\n"
	  	if [200, 401].include?(response[:status]) and !(response[:text].start_with?("\"<!DOCTYPE"))
	  		inst_app.configs[:inputs]['version'] = 'classic'
        Rails.logger.debug "Classic detected; code=#{response[:status]}, html?=#{response[:text][0..10]}\n"
	  		return true
  		elsif response[:status] == 404 or response[:text].start_with?("\"<!DOCTYPE")
  			Rails.logger.debug "Both APIs of batchbook return error."
	  		raise VersionDetectionError, 'Unable to detect the Batchbook version used. Please check the domain.'
  		end
  	end
  	false
  end

end
