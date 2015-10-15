class Integrations::QuickbooksUtil

	include Integrations::OauthHelper

	def remove_app_from_qbo(installed_app)
		remote_integ_map = Integrations::QuickbooksRemoteUser.where(:account_id => installed_app.account_id, :remote_id => installed_app.configs_company_id).first
		unless remote_integ_map.nil?
			remote_integ_map.destroy
		end

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

  def add_remote_integrations_mapping(installed_app)
  	remote_integ_map = Integrations::QuickbooksRemoteUser.where(:remote_id => installed_app.configs_company_id).first
  	if remote_integ_map.present?
			remote_integ_map.account_id = installed_app.account_id
			remote_integ_map.configs = { :user_id => User.current.id, :user_email => User.current.email }
			remote_integ_map.save
  	else
	  	Integrations::QuickbooksRemoteUser.create!(:account_id => installed_app.account_id, :remote_id => installed_app.configs_company_id,
	  		:configs => { :user_id => User.current.id, :user_email => User.current.email })
	  end
  end

end
