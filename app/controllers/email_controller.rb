#By shan .. Need to introduce delayed jobs here.
#Right now commented out delayed_job, with regards to the size of attachments and other things.
#In future, we can just try using delayed_jobs for non-attachment mails or something like that..
require 'charlock_holmes'
class EmailController < ApplicationController

  include EnvelopeParser
  include EmailHelper

  skip_filter :select_shard
  skip_before_filter :check_privilege
  skip_before_filter :verify_authenticity_token
  skip_before_filter :unset_current_account, :set_current_account, :check_session_timeout
  skip_before_filter :check_account_state, :except => [:show,:index]
  skip_before_filter :set_time_zone, :check_day_pass_usage 
  skip_before_filter :set_locale, :force_utf8_params
  skip_before_filter :logging_details
  skip_before_filter :ensure_proper_protocol
  skip_before_filter :ensure_proper_sts_header
  skip_after_filter :set_last_active_time

  before_filter :authenticate_request, :only => [:validate_domain, :account_details]

  def new
    render :layout => false
  end

  def create
    envelope = params[:envelope]
    request_url = ""
    request_url_hash = {}
    if request && request.url.present?
      request_url = request.url
      request_url_hash = {:request_url => request_url}
    end
    params.merge!(request_url_hash)
    params[:html] = Nokogiri::HTML(params[:html]).to_html if (!params[:html].nil? && !params[:html].blank?)
    if envelope.present? && multiple_envelope_to_address?( envelope_to = get_to_address_from_envelope(envelope))
     status = process_email_for_each_to_email_address(envelope_to)
    else
      @process_email = Helpdesk::ProcessEmail.new(params) 
      status =  @process_email.perform
    end
    status = (status == MAINTENANCE_STATUS ? :service_unavailable : :ok )
    render :layout => 'email', :status => status
  end

  def validate_domain
    domain = params[:domain]
    domain_mapping = DomainMapping.find_by_domain(domain)
    if domain_mapping.blank?
      render :json => {:domain_status => 404, :user_status => :not_found, :created_at => nil, :account_type => nil, :account_id => nil}
    else
      shard = ShardMapping.lookup_with_domain(domain)
      pod_info = shard.present? ? shard.pod_info : nil
      redirect_email(pod_info) if pod_info.present? && PodConfig['CURRENT_POD'] != pod_info
      shard_status = shard.status
      if shard.ok?
        Sharding.select_shard_of(domain) do
          Sharding.run_on_slave do
            account = Account.find_by_full_domain(domain).make_current
            account_type = account.email_subscription_state
            user = account.all_users.find_by_email(params[:email])
            basic_hash = {:domain_status => shard_status, :created_at => account.created_at, :account_type => account_type, :account_id => account.id}
            if user.nil?
              render :json => {:user_status => :not_found}.merge(basic_hash)
            elsif user.valid_user?
              render :json => {:user_status => :active}.merge(basic_hash)
            elsif user.deleted?
              render :json => {:user_status => :deleted}.merge(basic_hash)
            elsif user.blocked?
              render :json => {:user_status => :blocked}.merge(basic_hash)
            else
              render :json => {:user_status => :not_active}.merge(basic_hash)
            end
          end
        end
      else
        render :json => { :domain_status => shard_status, :user_status => :not_found, :created_at => nil, :account_type => nil, :account_id => nil}
      end
    end
  end

  def account_details
    account_id = params[:account_id]
    Sharding.admin_select_shard_of(account_id) do
      Sharding.run_on_slave do
        account = Account.find_by_id(account_id).make_current
        subscription_type = account.email_subscription_state
        render :json => { :status => 200, :created_at => account.created_at, :account_domain => account.full_domain, :account_verified => account.verified?, :subscription_type => subscription_type, :mrr => account.subscription.cmrr, :signup_score => account.ehawk_reputation_score, :antispam_enabled => true }
      end
    end
  rescue => e
    render :json => { :status => 404, :created_at => nil, :account_domain => nil, :account_verified => nil, :subscription_type => nil, :mrr => nil, :signup_score => nil, :antispam_enabled => nil }
  end

  private

  def authenticate_request
    render_404 unless ((params[:username] == "freshdesk" and params[:api_key] == Helpdesk::EMAIL[:domain_validation_key]) || authenticated_email_service_request?(request.authorization))
  end

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
    # redirect_url should match with the location directive in Nginx Proxy
    redirect_url = "@pod_redirect_#{pod_info}"
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
          if ((t_format == :subject || t_format == :headers) && (charsets[t_format.to_s].blank? || charsets[t_format.to_s].upcase == "UTF-8") && (!params[t_format].valid_encoding?))
            begin
              params[t_format] = params[t_format].encode(Encoding::UTF_8, :undef => :replace, 
                                                                      :invalid => :replace, 
                                                                      :replace => '')
              next
            rescue Exception => e
              Rails.logger.error "Error While encoding in process email  \n#{e.message}\n#{e.backtrace.join("\n\t")} #{params}"
            end
          end
          replacement_char = "\uFFFD"
          if t_format.to_s == "subject" and (params[t_format] =~ /^=\?(.+)\?[BQ]?(.+)\?=/ or params[t_format].include? replacement_char)
            params[t_format] = decode_subject
          else
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
              elsif ((charsets[t_format.to_s].blank? || charsets[t_format.to_s].upcase == "UTF-8") && (!params[t_format].valid_encoding?))
                  replace_invalid_characters t_format
              else
                Rails.logger.error "Error While encoding in process email  \n#{e.message}\n#{e.backtrace.join("\n\t")} #{params}"
                NewRelic::Agent.notice_error(e,{:description => "Charset Encoding issue with ===============> #{charset_encoding}"})
              end
            end
          end
        end
      end
  end

  def decode_subject
    subject = params[:subject]
    replacement_char = "\uFFFD"
    if subject.include? replacement_char
      params[:headers] =~ /^subject\s*:(.+)$/i
      subject = $1.strip
      unless subject =~ /=\?(.+)\?[BQ]?(.+)\?=/
        detected_encoding = CharlockHolmes::EncodingDetector.detect(subject)
        detected_encoding = "UTF-8" if detected_encoding.nil?
        begin
          decoded_subject = subject.force_encoding(detected_encoding).encode(Encoding::UTF_8, :undef => :replace, 
                                                                            :invalid => :replace, 
                                                                            :replace => '')
        rescue Exception => e
          decoded_subject = subject.force_encoding("UTF-8").encode(Encoding::UTF_8, :undef => :replace, 
                                                                    :invalid => :replace, 
                                                                    :replace => '')
        end
        subject = decoded_subject if decoded_subject
      end
    end
    if subject =~ /=\?(.+)\?[BQ]?(.+)\?=/
      decoded_subject = ""
      subject_arr = subject.split("?=")
      subject_arr.each do |sub|
        decoded_string = Mail::Encodings.unquote_and_convert_to("#{sub}?=", 'UTF-8')
        decoded_subject << decoded_string
      end
      subject = decoded_subject.strip
    end
    subject
  end
end
