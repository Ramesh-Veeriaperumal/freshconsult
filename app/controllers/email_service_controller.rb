require 'new_relic/agent/instrumentation/controller_instrumentation'
require 'new_relic/agent/instrumentation/rails3/action_controller'

class EmailServiceController < Fdadmin::MetalApiController

  include ActionController::HttpAuthentication::Basic::ControllerMethods
  include ActionController::Redirecting
  include NewRelic::Agent::Instrumentation::ControllerInstrumentation
  include NewRelic::Agent::Instrumentation::Rails3::ActionController
  
  append_view_path "#{Rails.root}/app/views"

  include Concerns::ApplicationConcern
  include EnvelopeParser
  include Helpdesk::Email::Constants
  include AccountConstants
  include EmailHelper

  before_filter :http_authenticate
  before_filter :determine_pod, :only => [:new, :create]
  before_filter :check_account_status, :only => [:new, :create]
  before_filter :check_user_status, :only => [:new, :create]
  before_filter :set_default_locale, :set_msg_id

  def new
  	render :layout => false
  end

  def create
    incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
    incoming_email_handler.perform 
    head :ok, content_type: "text/html"
  end

  def spam_threshold_reached
    block_spam_account params
    render status: :ok, :json => { :request_id => Thread.current[:message_uuid][0], :success => true, :message => nil}
  end

  private

  def determine_pod
    pod_info = find_pod
    if pod_info.present? && !email_for_current_pod?(pod_info)
      Rails.logger.error "Email is not for the current POD."
      redirect_email(pod_info) and return
    end
  end

  def find_pod
      to_emails = parse_to_emails(params)
      to_email_domain = to_emails.first[:domain]
      shard = ShardMapping.fetch_by_domain(to_email_domain)
      return pod_info = shard.present? ? shard.pod_info : nil
  end

  def email_for_current_pod?(pod_info)
    return PodConfig['CURRENT_POD'] == pod_info
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

  def http_authenticate
      if (!authenticated_email_service_request?(request.authorization))
        Rails.logger.info "Authorization Failed"
        render status: :forbidden, :json => { :request_id => Thread.current[:message_uuid][0], :success => false, :message => "Autherization Failed"}
      end
  end

  def check_user_status
    Sharding.run_on_shard(@shard.shard_name) do
      account = Account.find_by_full_domain(@domain)
      if (!account.nil? and account.allow_incoming_emails?)
        email = get_user_from_email(params[:from])
        user = account.user_emails.user_for_email(email)
        if (!user.nil? and user.blocked?)
          Rails.logger.info "Email Processing Failed: User is blocked!, account_id: #{account.id}"
          head :ok, content_type: "text/html"
        end
      else
        if account.nil?
          Rails.logger.info "Email Processing Failed: Account is nil, envelope_to: #{JSON.parse(params[:envelope])["to"]}"
        else
          Rails.logger.info "Email Processing Failed: Account is not active, account_id: #{account.id}"
        end
        head :ok, content_type: "text/html"
      end
    end
  rescue => e
    Rails.logger.info "Error in check_user_status: #{e.message} - #{e.backtrace[0..10]}"
  end
end
