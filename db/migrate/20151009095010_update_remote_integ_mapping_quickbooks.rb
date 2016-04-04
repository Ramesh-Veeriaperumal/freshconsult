include Integrations::OauthHelper

class UpdateRemoteIntegMappingQuickbooks < ActiveRecord::Migration

	shard :all
	
  def up
		app = Integrations::Application.find_by_name("quickbooks")
		Integrations::InstalledApplication.where(:application_id => app.id).all.each do |inst_app|
			begin
				inst_app.account.make_current

				headers = {
					'Accept' => 'application/json',
					'Content-Type' => 'application/json'
				}
				resp = get_oauth1_response({
					:app_name => "quickbooks",
					:method => :get,
					:url => "https://appcenter.intuit.com/api/v1/user/current",
					:body => nil,
					:headers => headers,
					:installed_app => inst_app
				})

				resp = Hash.from_xml(resp.body) if (resp.body.include? 'xml')

				user_id = ""

				if resp["UserResponse"] && resp["UserResponse"]["User"]
					email = resp["UserResponse"]["User"]["EmailAddress"]
					if email
						user = Account.current.user_emails.user_for_email(email)
						user_id = user.id if user.present?
					end
				end

				Integrations::QuickbooksRemoteUser.create(:account_id => Account.current.id,
		      :remote_id => inst_app.configs_company_id, :configs => { :user_id => user_id, :user_email => email })
			rescue => e
			end
		end
  end

  def down
  	Integrations::QuickbooksRemoteUser.delete_all
  end
end
