module Integrations::Sugarcrm::ApiUtil
include Integrations::Sugarcrm::Constants


def fetch_session_id
	rest_data = SESSION_REST_DATA % {:username => @installed_app["configs"][:inputs]["username"], :password => @installed_app["configs"][:inputs]["password"] }
	content = SUGARAPI % {:method => "login", :rest_data => rest_data }
	session_response = get_data(content)
	parse_response(session_response, ID)
end

def get_custom_fields_api key
	rest_data = CUSTOM_FIELDS_REST_DATA % {:session_id => @installed_app["configs"][:inputs]["session_id"], :module_name => "#{key.capitalize}s"}
	content = SUGARAPI % {:method => "get_module_fields", :rest_data => rest_data}
	response = get_data(content)
	parse_response(response, MODULE_FIELDS)
end

private

	def get_data content
		params = QUERY_PARAMS
		params[:domain] = @installed_app["configs"][:inputs]["domain"]
		params[:body] = content 
		httpRequestProxy = HttpRequestProxy.new
		response = httpRequestProxy.fetch_using_req_params(params, {})
	end

	def parse_response response, evt
		if (response[:text] != "null" && response[:status] == 200)
			if((ERROR_CODE.has_value? (JSON.parse(response[:text])["number"])) rescue nil)
			  unless evt == ID
				  @installed_app["configs"][:inputs].delete("session_id") 
				  get_session_id
			  end
				{:response_status => false, :error_name => JSON.parse(response[:text])["name"]}
			else 
				if((JSON.parse(response[:text])[evt].present?) rescue nil)
					{:response_status => true, :data => JSON.parse(response[:text])[evt]}
				else
					{:response_status => false, :error_name => t(:'integrations.sugarcrm.form.error') } 
				end
			end
		else
			{:response_status => false, :error_name => t(:'integrations.sugarcrm.form.error') }
		end
	end

end