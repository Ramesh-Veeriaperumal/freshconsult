class MailgunController < ApplicationController

  
  skip_filter :select_shard
  before_filter :access_denied, :unless => :mailgun_verifed
  skip_before_filter :check_privilege
  skip_before_filter :verify_authenticity_token
  skip_before_filter :unset_current_account, :set_current_account, :redirect_to_mobile_url
  skip_before_filter :check_account_state, :except => [:show,:index]
  skip_before_filter :set_time_zone, :check_day_pass_usage 
  skip_before_filter :set_locale, :force_utf8_params
  skip_before_filter :logging_details, :ensure_proper_protocol
  skip_after_filter :set_last_active_time

  def create
    @process_email.perform
    render :nothing => true, :status => 200, :content_type => 'text/html'
  end

  private

    # def log_file
    #   @log_file_path = "#{Rails.root}/log/incoming_email.log"      
    # end

    # def logging_format
    #   @log_file_format = %(from_email : #{params[:from]}, to_emails : #{params["To"]}, envelope : #{params[:recipient]})
    # end

    def determine_pod

      # Rails.logger.info "Params: #{params}."
      @process_email = Helpdesk::Email::Process.new(params)
      pod_info = @process_email.determine_pod

      if PodConfig['CURRENT_POD'] != pod_info
        Rails.logger.error "Email is not for the current POD."
        redirect_email(pod_info) and return
      end
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

    def mailgun_verifed
      return params["signature"] == OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'),
                                                            MailgunConfig['api_key'],
                                                            '%s%s' % [params["timestamp"], params["token"]])
    end
end