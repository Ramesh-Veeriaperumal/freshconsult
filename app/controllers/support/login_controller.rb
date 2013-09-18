class Support::LoginController < SupportController

	include Redis::RedisKeys
	include Redis::TicketsRedis
	
	skip_before_filter :check_account_state
	after_filter :set_domain_cookie, :only => :create
	
	def new
		if current_account.sso_enabled? and check_request_referrer 
		  	redirect_to current_account.sso_options[:login_url]
		else
		  	@user_session = current_account.user_sessions.new
			set_portal_page :user_login
		end
	end

	def create   
		@user_session = current_account.user_sessions.new(params[:user_session])
		if @user_session.save
			#Temporary hack due to current_user not returning proper value
			@current_user_session = @user_session
			@current_user = @user_session.record
			#Hack ends here

			remove_old_filters if @current_user.agent?

			redirect_back_or_default('/') if grant_day_pass 
			#Unable to put 'grant_day_pass' in after_filter due to double render
		else
			note_failed_login
			set_portal_page :user_login
			render :action => :new
		end
	end

	private
		def note_failed_login
			user_info = params[:user_session][:email] if params[:user_session]
			logger.warn "Failed login for '#{user_info.to_s}' from #{request.remote_ip} at #{Time.now.utc}"
	    end

	    def remove_old_filters
	      remove_tickets_redis_key(HELPDESK_TICKET_FILTERS % {:account_id => current_account.id, :user_id => current_user.id, :session_id => session.session_id})
	    end

      def check_request_referrer
        request.referrer ? (URI(request.referrer).path != "/login/normal") : true
      end

    def set_domain_cookie
    	if @current_user and @current_user.helpdesk_agent? and current_portal
     		cookies[:helpdesk_url] = current_portal.host
     	end
    end      
end

