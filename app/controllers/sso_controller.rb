class SsoController < ApplicationController
	def login
		auth = Authorization.find_by_provider_and_uid_and_account_id(params['provider'], params['uid'], current_account.id)
		unless auth.blank?
			curr_user = auth.user 
			#verify_fb_pending(curr_user)
			kv = KeyValuePair.find_by_account_id_and_key(current_account.id, curr_user.id)
			random_hash = Digest::MD5.hexdigest(kv.value)
			expiry = kv.value.to_i + 60000 
			curr_time = (DateTime.now.to_f * 1000).to_i
			if(kv.blank? == false and random_hash == params['challenge'] and curr_time <= expiry)
				user_session = curr_user.account.user_sessions.new(curr_user) 
				kv.delete
				redirect_back_or_default('/') if user_session.save
			else
				flash[:notice] = t(:'flash.g_app.authentication_failed')
      	redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
			end
		end
	end

	def facebook
		redirect_to "#{AppConfig['integrations_url'][Rails.env]}/auth/facebook?origin=#{current_portal.id}"
	end


end
