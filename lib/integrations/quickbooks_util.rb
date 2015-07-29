class Integrations::QuickbooksUtil

	include Integrations::OauthHelper

	def remove_app_from_qbo(installed_app)
		headers = {
			'Accept' => 'application/json',
			'Content-Type' => 'application/json'
		}
		get_oauth1_response({
			:app_name => Integrations::Constants::APP_NAMES[:quickbooks],
			:method => :get,
			:url => Integrations::Quickbooks::Constant::DISCONNECT_URI,
			:body => nil,
			:headers => headers,
			:installed_app => installed_app
		})
  end

end
