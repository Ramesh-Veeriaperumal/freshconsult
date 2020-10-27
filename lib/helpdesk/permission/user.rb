module Helpdesk::Permission
	module User
	 
    include Helpdesk::Permission::Util
    include Portal::PortalUrl

    def has_login_permission?(email, account = Account.current )
      valid_permissible_user?(email, account)
    end

    def has_signup_permission?(email, account = Account.current )
      valid_permissible_domain?(email, account)
    end

    def redirect_on_login_permission_fail(account, portal_id = 0)
      nmobile_login
      handle_login_redirect(account, portal_id)
    end

    def redirect_on_signup_permission_fail(account, portal_id = 0)
      handle_signup_redirect(account, portal_id, signup_access_denied_message)
    end

    def handle_fb_redirect(account, portal_id = 0)
      redirect_on_login_permission_fail(account, portal_id)
    end

    private
      def login_access_denied_message
        access_denied_with_message(t('flash.login.login_permission_denied'))
      end

      def signup_access_denied_message
        access_denied_with_message(t('flash.login.signup_permission_denied'))
      end

      def access_denied_with_message(permission_denied)
        "<div align= 'center'> #{permission_denied}. <br> #{t("flash.login.contact_administrator")} </div>"
      end

      def handle_login_redirect(account, portal_id = 0)
        redirect_url = redirect_portal_url(account, portal_id) + support_login_path(:restricted_helpdesk_login_fail => true)
        redirect_to redirect_url
      end

      def handle_signup_redirect(account, portal_id = 0, message = signup_access_denied_message)
        redirect_url = redirect_portal_url(account, portal_id) + support_login_path
        redirect_to redirect_url, notice: message
      end

      def redirect_portal_url account, portal_id = 0   
        portal_url_from_id portal_id, account
      end

      def nmobile_login
        if is_native_mobile?
          cookies["mobile_access_token"] = { :value => 'customer', :http_only => true } 
        end
      end
		
	end
end