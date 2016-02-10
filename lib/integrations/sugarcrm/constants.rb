module Integrations::Sugarcrm::Constants


SUGARAPI = %Q|method=%{method}&input_type=JSON&response_type=JSON&rest_data=%{rest_data}|

SESSION_REST_DATA = %Q|{"user_auth" : {"user_name" : "%{username}", "password" : "%{password}", "version" : 4},"application": "freshdesk_sugarcrm"}|

CUSTOM_FIELDS_REST_DATA = %Q|{"session": "%{session_id}","module_name":"%{module_name}"}|

QUERY_PARAMS = {
	:rest_url => "service/v4/rest.php",
	:method => :post,
	:ssl_enabled => false,
	:username => 'null',
	:password => 'x',
	:accept_type => '',
	:content_type => ''
}

ERROR_CODE = {
	:invalid_user => 10, #10 => invalid usr_id or password in sugarCRM
	:invalid_session_id => 11 # 11 => invalid session id error.
}

ID = "id"

MODULE_FIELDS =  "module_fields"

# UNSUPPORTED_DATA_TYPE = ["relate", "html", "password", "link"] //blacklisted

SUPPORTED_DATA_TYPE = ["bool", "id", "fullname", "datetime", "assigned_user_name", "text", "team_list", "email", "varchar", "enum", "phone", "image", "date", "username", "int", "url", "name", "currency", "decimal", "encrypt", "float", "iframe", "multienum", "radioenum", "currency_id"]

end

