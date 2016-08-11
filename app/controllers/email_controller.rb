#By shan .. Need to introduce delayed jobs here.
#Right now commented out delayed_job, with regards to the size of attachments and other things.
#In future, we can just try using delayed_jobs for non-attachment mails or something like that..
class EmailController < ApplicationController

  include EnvelopeParser

  skip_filter :select_shard
  skip_before_filter :check_privilege
  skip_before_filter :verify_authenticity_token
  skip_before_filter :unset_current_account, :set_current_account, :redirect_to_mobile_url
  skip_before_filter :check_account_state, :except => [:show,:index]
  skip_before_filter :set_time_zone, :check_day_pass_usage 
  skip_before_filter :set_locale, :force_utf8_params
  skip_before_filter :logging_details
  skip_before_filter :ensure_proper_protocol
  skip_after_filter :set_last_active_time
  
  def new
    render :layout => false
  end

  def create
    envelope = params[:envelope]
    if envelope.present? && multiple_envelope_to_address?( envelope_to = get_to_address_from_envelope(envelope))
     status = process_email_for_each_to_email_address(envelope_to)
    else
      @process_email = Helpdesk::ProcessEmail.new(params)
      status =  @process_email.perform 
    end
    status = (status == MAINTENANCE_STATUS ? :service_unavailable : :ok )
    render :layout => 'email', :status => status
  end

  private

  def determine_pod
    pod_infos = find_pods
    unless email_for_current_pod?(pod_infos)
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
        pod_infos.push(pod_info)
    end
    return pod_infos
  end

  def email_for_current_pod?(pod_infos)
    pod_infos.each do |pod_info|
      return true if PodConfig['CURRENT_POD'] == pod_info
    end
    return false
  end

  def process_email_for_each_to_email_address(envelope_to)
    encode_param_fields 
    status = MAINTENANCE_STATUS
    envelope_to.each_with_index do |to_address, i|
      envelope_params = ActiveSupport::JSON.decode(params[:envelope]).with_indifferent_access
      envelope_params[:to] = Array.new.push(to_address)
      params[:envelope] = envelope_params.to_json
      Rails.logger.info "Multiple Recipient case - starting Process email for :#{to_address} "
      process_email = Helpdesk::ProcessEmail.new(params)
       status = nil if process_email.perform(@to_emails[i], true) != MAINTENANCE_STATUS
    end
    status
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

  #can be moved to a separate module
  def encode_param_fields
      charsets = params[:charsets].blank? ? {} : ActiveSupport::JSON.decode(params[:charsets])
      [ :html, :text, :subject, :headers, :from ].each do |t_format|
        unless params[t_format].nil?
          charset_encoding = (charsets[t_format.to_s] || "UTF-8").strip()
          # if !charset_encoding.nil? and !(["utf-8","utf8"].include?(charset_encoding.downcase))
            begin
              params[t_format] = Iconv.new('utf-8//IGNORE', charset_encoding).iconv(params[t_format])
            rescue Exception => e
              mapping_encoding = {
                "ks_c_5601-1987" => "CP949",
                "unicode-1-1-utf-7"=>"UTF-7",
                "_iso-2022-jp$esc" => "ISO-2022-JP",
                "charset=us-ascii" => "us-ascii",
                "iso-8859-8-i" => "iso-8859-8",
                "unicode" => "utf-8"
              }
              if mapping_encoding[charset_encoding.downcase]
                params[t_format] = Iconv.new('utf-8//IGNORE', mapping_encoding[charset_encoding.downcase]).iconv(params[t_format])
              else
                Rails.logger.error "Error While encoding in process email  \n#{e.message}\n#{e.backtrace.join("\n\t")} #{params}"
                NewRelic::Agent.notice_error(e,{:description => "Charset Encoding issue with ===============> #{charset_encoding}"})
              end
            end
          # end
        end
      end
  end


end
