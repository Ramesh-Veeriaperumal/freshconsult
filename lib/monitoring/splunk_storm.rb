require 'rest-client'

class Monitoring::SplunkStorm

@queue = 'metrics_data'

API_VERSION = 1
API_ENDPOINT = 'inputs/http'

def self.perform(args)
	event_params = {:sourcetype => 'json_no_timestamp', :host => SplunkConfig[Rails.env]['host']}
	event_params[:project] = SplunkConfig[Rails.env]['project_id']

	api_url = "https://api.splunkstorm.com"
	api_params = URI.escape(event_params.collect{|k,v| "#{k}=#{v}"}.join('&'))
	endpoint_path = "#{API_VERSION}/#{API_ENDPOINT}?#{api_params}"

	request = RestClient::Resource.new(api_url, :user =>'x', :password => SplunkConfig[Rails.env]['access_token'])
	response = request[endpoint_path].post(args.to_json,:content_type => 'json')
 end

end