class MailgunController < ApplicationController

  
  skip_filter :select_shard
  before_filter :access_denied, :unless => :mailgun_verifed
  skip_before_filter :determine_pod
  skip_before_filter :check_privilege
  skip_before_filter :verify_authenticity_token
  skip_before_filter :unset_current_account, :set_current_account, :redirect_to_mobile_url
  skip_before_filter :check_account_state, :except => [:show,:index]
  skip_before_filter :set_time_zone, :check_day_pass_usage 
  skip_before_filter :set_locale, :force_utf8_params
  skip_before_filter :logging_details

  def create
    Helpdesk::Email::Process.new(params).perform
    render :nothing => true, :status => 200, :content_type => 'text/html'
  end

  private

    # def log_file
    #   @log_file_path = "#{Rails.root}/log/incoming_email.log"      
    # end

    # def logging_format
    #   @log_file_format = %(from_email : #{params[:from]}, to_emails : #{params["To"]}, envelope : #{params[:recipient]})
    # end

    def mailgun_verifed
      return params["signature"] == OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'),
                                                            MailgunConfig['api_key'],
                                                            '%s%s' % [params["timestamp"], params["token"]])
    end
end