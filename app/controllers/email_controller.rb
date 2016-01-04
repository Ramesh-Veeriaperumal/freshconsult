#By shan .. Need to introduce delayed jobs here.
#Right now commented out delayed_job, with regards to the size of attachments and other things.
#In future, we can just try using delayed_jobs for non-attachment mails or something like that..

class EmailController < ApplicationController

  skip_filter :select_shard
  skip_before_filter :determine_pod
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
    # Delayed::Job.enqueue Helpdesk::ProcessEmail.new(params)
    Helpdesk::ProcessEmail.new(params).perform
    render :layout => 'email'
  end

  private

    # def log_file
    #   @log_file_path = "#{Rails.root}/log/incoming_email.log"      
    # end

    # def logging_format
    #   @log_file_format = %(from_email : #{params[:from]}, to_emails : #{params[:to]}, envelope : #{params[:envelope]})
    # end
end