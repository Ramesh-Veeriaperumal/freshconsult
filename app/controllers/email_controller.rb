#By shan .. Need to introduce delayed jobs here.
#Right now commented out delayed_job, with regards to the size of attachments and other things.
#In future, we can just try using delayed_jobs for non-attachment mails or something like that..

class EmailController < ApplicationController
 
  skip_filter :select_shard
  skip_before_filter :verify_authenticity_token
  skip_before_filter :redirect_to_mobile_url
  skip_before_filter :check_account_state, :except => [:show,:index]
  skip_before_filter :set_time_zone, :check_day_pass_usage 
  skip_before_filter :set_locale
  
  def new
    render :layout => false
  end

  def create
    # Delayed::Job.enqueue Helpdesk::ProcessEmail.new(params)
    Helpdesk::ProcessEmail.new(params).perform
    render :layout => 'email'
  end

end