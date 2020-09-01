class AnnouncementsController < ApplicationController

  PRODUCT_UPDATES = YAML::load_file(File.join(Rails.root, 'config', 'announcements.yml'))[Rails.env]
  ACCOUNT_URL = PRODUCT_UPDATES['account_url']
  ACCOUNT_SHARED_SECRET = PRODUCT_UPDATES['shared_secret']
  
  before_filter :load_variables
  before_filter :validate_params, only: [:account_login_url]

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

    def load_variables
      @user_name  = current_user.try(:name).to_s
      @user_email = current_user.try(:email).to_s
    end

    def validate_params
      return if params[:redirect_to].nil?
      portal_urls = current_account.portals.pluck(:portal_url).compact.uniq
      portal_domains = portal_urls.map { |url| get_host_without_www(url) }
      redirect_to_domain = get_host_without_www(params[:redirect_to])
      unless(ACCOUNT_URL == redirect_to_domain || request.domain == redirect_to_domain || portal_domains.include?(redirect_to_domain))
        Rails.logger.error "Invalid redirect_to param : #{params.inspect}"
        render_404
      end
    end

    def get_host_without_www(url)
      return nil unless url.present?
      uri  = URI.parse(url)
      uri  = URI.parse("http://#{url}") if uri.scheme.nil?
      host = uri.host.downcase
      host.start_with?('www.') ? host[4..-1] : host
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
