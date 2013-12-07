class Social::FacebookSubscriptionController < Admin::AdminController

  skip_before_filter :check_privilege, :only =>[:subscription]
  include Facebook::KoalaWrapper::ExceptionHandler
  
  #this controller is only for testing locally without node support
  def subscription
    begin
      if request.get?
        if params['hub.mode'] =='subscribe' && params['hub.verify_token'] =='tokenforfreshdesk'
          render :text => params['hub.challenge']
        else
          render :text => 'Failed to authorize facebook challenge request'
        end
      elsif request.post?
        updated_obj = request.body.read if request.body
        #Resque.enqueue(Worker::FacebookRealtime,{:feed_object => updated_obj}) if updated_obj
        Social::FacebookSubscriptionController.process_facebook_request(updated_obj)
        render :text => "Thanks for the update"
      else
        render :text => "This type of request not allowed"
      end
    rescue Exception => e
      Rails.logger.error "Error while processing Facebook request =============> #{e.inspect}"
      NewRelic::Agent.notice_error(e,{:description => "Error while processing Facebook request"})
      render :text => "Request cannot be processed"
    end
  end

  def self.process_facebook_request(feed_object)
    sandbox do
      Facebook::Core::Parser.new(feed_object).parse
    end
  end

end
