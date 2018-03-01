class AnnouncementsController < ApplicationController

  PRODUCT_UPDATES = YAML::load_file(File.join(Rails.root, 'config', 'announcements.yml'))[Rails.env]
  ACCOUNT_URL = PRODUCT_UPDATES['account_url']
  ACCOUNT_SHARED_SECRET = PRODUCT_UPDATES['shared_secret']
  
  before_filter :check_feature, :load_variables

  def account_login_url
    redirect_to generate_account_login_url(params[:redirect_to])
  end

  def index
    @announcement_bucket = current_account.account_additional_settings.additional_settings[:announcement_bucket]
    @state  = current_account.subscription.state
    @role = current_user.privilege?(:admin_tasks) ? :'admin' : :'agent'
    @plan_name = current_account.plan_name
  end

  private 

    def check_feature
      current_account.announcements_tab_enabled?
    end

    def load_variables
      @user_name  = current_user.try(:name).to_s
      @user_email = current_user.try(:email).to_s
    end
   
    def generate_account_login_url redirect_to
      time_stamp = Time.now.getutc.to_i.to_s
      sso_hash = OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new('MD5'),
        ACCOUNT_SHARED_SECRET,
        @user_name+ACCOUNT_SHARED_SECRET+@user_email+time_stamp)
      "https://#{ACCOUNT_URL}/login/sso?name=#{@user_name}&email=#{@user_email}&hash=#{sso_hash}&timestamp=#{time_stamp}&redirect_to=#{redirect_to}"
    end

end
