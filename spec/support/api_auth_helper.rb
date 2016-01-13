require 'json-compare'
require 'active_support/core_ext'

module APIAuthHelper

  def http_login(user)
    apiKey = user.single_access_token
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(apiKey,"X")
  end

  def parse_json(response)
  	@json = JSON.parse(response.body)
  end

  def parse_xml(response)
    Hash.from_trusted_xml(response.body)
  end

  def compare(input,output,exclusions={})
  	JsonCompare.get_diff(input,output,exclusions)
  end

  def compare_keys(input,output,exclusions = {})
    result = JsonCompare.get_diff(input.keys,output.keys,exclusions)
  end

  def assert_array(first_input, second_input, exclusions = [])
    ((first_input - second_input) - exclusions).empty?
  end

end
 
