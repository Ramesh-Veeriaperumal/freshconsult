#By shan .. Need to introduce delayed jobs here.
#Right now commented out delayed_job, with regards to the size of attachments and other things.
#In future, we can just try using delayed_jobs for non-attachment mails or something like that..

class EmailController < ApplicationController
  skip_before_filter :verify_authenticity_token
  skip_before_filter :set_time_zone
  
  def new
    render :layout => 'application'
  end

  def create
    #Delayed::Job.enqueue Helpdesk::ProcessEmail.new(params)
    Helpdesk::ProcessEmail.new(params).perform
    
    render :layout => 'email'
  end

end
