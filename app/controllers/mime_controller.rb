require 'new_relic/agent/instrumentation/controller_instrumentation'
require 'new_relic/agent/instrumentation/rails3/action_controller'
require 'new_relic/agent/instrumentation/rails3/errors'

class MimeController < Fdadmin::MetalApiController

  include ActionController::Redirecting
  include NewRelic::Agent::Instrumentation::ControllerInstrumentation
  include NewRelic::Agent::Instrumentation::Rails3::ActionController
  include NewRelic::Agent::Instrumentation::Rails3::Errors
  
  append_view_path "#{Rails.root}/app/views"

  include Concerns::ApplicationConcern
  include EnvelopeParser
  include Helpdesk::Email::Constants

  before_filter :determine_pod
  before_filter :check_email_size, :check_account_status, :check_user_status
  before_filter :set_default_locale, :set_msg_id

  def new
  	render :layout => false
  end

  def create
    email_handler = Helpdesk::Email::EmailHandler.new(params)
    email_handler.execute
    head :ok, content_type: "text/html"
  end

  private

  def determine_pod
    pod_infos = find_pods
    if pod_infos.present? && !email_for_current_pod?(pod_infos)
      Rails.logger.error "Email is not for the current POD."
      redirect_email(pod_infos.first) and return
    end
  end

  def find_pods
      @to_emails = parse_to_emails(params)
      pod_infos = []
      @to_emails.each do |to_email|
        shard = ShardMapping.fetch_by_domain(to_email[:domain])
        pod_info = shard.present? ? shard.pod_info : nil
        pod_infos.push(pod_info) if pod_info.present?
    end
    return pod_infos
  end

  def email_for_current_pod?(pod_infos)
    pod_infos.each do |pod_info|
      return true if PodConfig['CURRENT_POD'] == pod_info
    end
    return false
  end
  
  def redirect_email(pod_info)
    # mail is redirected to the correct pod, using Nginx X-Accel-Redirect. There is no redirect sent to Sendgrid.
    redirect_url = "/pod_redirect/#{pod_info}" #Should match with the location directive in Nginx Proxy
    Rails.logger.info "Redirecting to the correct POD. Redirect URL is #{redirect_url}"
    response.headers["X-Accel-Redirect"] = redirect_url
    response.headers["X-Accel-Buffering"] = "off"
    Rails.logger.info "Response body : #{response.body}"
    redirect_to redirect_url and return
  end

  def set_default_locale
    I18n.locale = I18n.default_locale
  end

  def check_account_status
    @domain = get_domain_from_envelope(params[:envelope])
    @shard = ShardMapping.lookup_with_domain(@domain)

    if @shard.nil?
      Rails.logger.info "Shard Not Found for domain: #{@domain}"
      head :ok, content_type: "text/html"
    elsif !@shard.ok?
      Rails.logger.info "Domain Not Ready for domain #{@domain}"
      head :ok, content_type: "text/html"
    end
  end

  def check_user_status
    Sharding.run_on_shard(@shard.shard_name) do
      account = Account.find_by_full_domain(@domain)
      if (!account.nil? and account.active?)
        email = get_user_from_email(params[:from])
        user = account.user_emails.user_for_email(email)
        if (!user.nil? and user.blocked?)
          Rails.logger.info "Email Processing Failed: User is blocked!"
          head 200, content_type: "text/html"
        end
      else
        if account.nil?
          Rails.logger.info "Email Processing Failed: Account is nil"
        else
          Rails.logger.info "Email Processing Failed: Account is not active"
        end
        head 200, content_type: "text/html"
      end
    end
  rescue => e
    Rails.logger.info "Error in check_user_status: #{e.message} - #{e.backtrace}"
  end

  def check_email_size
    email_size = params[:email].bytesize
    if (email_size > MAX_EMAIL_SIZE)
      Rails.logger.info "Email Processing Failed: Email size - #{email_size} is greater than MAX SIZE LIMIT #{MAX_EMAIL_SIZE}"
      head 200, content_type: "text/html"
    end
  end

end
