class NewuiController < ApplicationController

  before_filter :require_login
  skip_before_filter :check_privilege


  # TODO
  # Logged in User Details(Agent details) - name , email ,phone , type etc
  # UerPermissin - Roles and Fine grained roles (IMPORTANT).
  # Org details (account details ) -- Organization Name, logo url, phone, top Admins
  # License details - license details - modules enabled, addons, agent count, trail or evaluation, expiry date
  # If we are going to have API key that details
  #
  # javascript CDN path
  # css CDN path
  # User customization
  # Organization customization
  #
  #
  # addon related stuff
  # tracking related stuffs
  #



  def index

    @buildnumber="1" #in ember finger printing will be disabled frontend build number will be update in db we need to fetch and use here

    @appinfojson=""
    @locale=current_user.language
    @langscript = "<script src='/new/assets/lang/"+@locale+".js?_"+@buildnumber+"'></script>"
    @scriptlet = "__a_inf("+@appinfojson+");"
    render :layout => false

  end

  private

  def require_login
      # Redirect to Login page for non login user
      unless current_user
        session[:return_to]=request.url
        redirect_to login_path
      end
  end

end
