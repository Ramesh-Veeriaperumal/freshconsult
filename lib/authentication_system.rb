module AuthenticationSystem
  
  def self.included(base)
    base.helper_method :current_user_session, :current_user
  end
  
  #### Need to remove this method - kiran
  def update_last_seen_at
  end

  private
    def current_user_session
      return @current_user_session if defined?(@current_user_session)
      @current_user_session = current_account.user_sessions.find
    end

    def log_out!
      current_user_session.destroy if current_user_session 
      @current_user = nil
      @current_user_session = nil
    end
  
    def current_user
      return @current_user if defined?(@current_user)
      @current_user = current_user_session && current_user_session.record
    end
  
    def require_user
      unless authorized?
        respond_to do |wants|
          wants.html do
            store_location
            flash[:notice] = "You must be logged in to access this page"
            redirect_to login_url
          end
          
          wants.json do
            render :json => { :error => 'Login required' }, :status => :unauthorized
          end
        end
        return false
      end
    end

    def require_no_user
      if current_user
        store_location
        flash[:notice] = "You must be logged out to access this page"
        redirect_to user_url
        return false
      end
    end
  
    def store_location
      session[:return_to] = request.fullpath
    end
  
    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end

    def authenticate_admin
      authenticate_or_request_with_http_basic do |user, password|
       	user == 'super' && password == 'SPIDEYd00per'
     	end
    end

    def logged_in?
      current_user
    end

    def authorized?
      current_user
    end

end
