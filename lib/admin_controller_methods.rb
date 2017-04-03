# This module, included by all controllers in the admin namespace,
# overrides AuthenticatedSystem methods to use browser-based
# authentication rather using a login form.
module AdminControllerMethods

   def self.included(base)
    base.send :prepend_before_filter, :check_admin_subdomain
    base.send :skip_before_filter, :check_privilege    
    base.send :skip_before_filter, :set_time_zone
    base.send :skip_before_filter, :set_current_account
    base.send :skip_before_filter, :set_locale
    base.send :skip_before_filter, :check_account_state
    base.send :skip_before_filter, :ensure_proper_protocol
    base.send :skip_before_filter, :check_day_pass_usage
    base.send :skip_filter, :select_shard
    base.send :layout, "subscription_admin"
    base.send :prepend_before_filter, :set_time_zone
    base.send :before_filter, :check_admin_user_privilege
    
  end
  
  protected
  
     def access_denied
       request_http_basic_authentication 'Admin Area'
     end
    
    def set_time_zone
      Time.zone = 'Pacific Time (US & Canada)'
    end
    
    def cumilative_count(&block)
      count = 0
      Sharding.run_on_all_slaves(&block).each { |result| count+=result }
      count
    end

    def merge_array_of_hashes(arr)
      arr.inject{|date, el| date.merge( el ){|k, old_v, new_v| old_v + new_v}}
    end

    # Since the default, catch-all routes at the bottom of routes.rb
    # allow the admin controllers to be accessed via any subdomain,
    # this before_filter prevents that kind of access, rendering
    # (by default) a 404.
    def check_admin_subdomain
      raise ActionController::RoutingError, "Not Found" unless admin_subdomain?
    end

    def current_user
      return @current_user if defined?(@current_user)
      @current_user_session = AdminSession.find
      @current_user = @current_user_session.record if @current_user_session

      @current_user
    end

    def current_user_session
      return @current_user_session if defined?(@current_user_session)
      activate_auth
      @current_user_session = AdminSession.find
      @current_user = @current_user_session.record if @current_user_session

      @current_user_session
    end

    def activate_auth
      Authlogic::Session::Base.controller = Authlogic::ControllerAdapters::RailsAdapter.new(self) unless Authlogic::Session::Base.controller
    end

    def last_request_update_allowed?
      false
    end
end