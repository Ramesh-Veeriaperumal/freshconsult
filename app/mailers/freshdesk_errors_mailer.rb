class FreshdeskErrorsMailer < ActionMailer::Base
  
  layout "email_font"
  
  def error_email(object, params, e, options={}) 
    headers = {
      :to  => (options[:recipients] || (Rails.env.production? ? Helpdesk::EMAIL[:production_dev_ops_email] : "dev-ops@freshpo.com") ),
      :from => Helpdesk::EMAIL[:default_requester_email],
      :subject => (options[:subject] || "Error in #{object.class.name}"),
      :sent_on => Time.now
    }
    @object = object
    @params = params
    @error  = e
    @additional_info = options[:additional_info]
    @query = options[:query]
    mail(headers) do |part|
      part.html { render "error_email" }
    end.deliver
  end 
  
  def error_in_crm(model) 
    headers = {
      :to    => AppConfig['billing_email'],
      :from  => "kiran@freshdesk.com",
      :cc    => "vijayaraj@freshdesk.com",
      :subject => "Error while adding to Marketo",
      :sent_on => Time.now
    }
    @model = model
    mail(headers) do |part|
      part.html { render "error_in_crm" }
    end.deliver
  end

  def spam_watcher(options={}) 
    headers = {
      :to     => Helpdesk::EMAIL[:spam_watcher],
      :from   => Helpdesk::EMAIL[:default_requester_email],
      :subject => (options[:subject] || "Abnormal load by spam watcher"),
      :sent_on => Time.now
    }
    @additional_info = options[:additional_info]
    mail(headers) do |part|
      part.html { render "spam_watcher" }
    end.deliver
  end 

  def spam_blocked_alert(options={}) 
    headers = {
      :to           =>  Helpdesk::EMAIL[:spam_watcher],
      :from         =>  Helpdesk::EMAIL[:default_requester_email],
      :subject      =>  (options[:subject] || "Abnormal load by spam watcher"),
      :sent_on      =>  Time.now
    }
    @additional_info = options[:additional_info]
    mail(headers) do |part|
      part.html { render "spam_blocked_alert", :formats => [:html] }
    end.deliver
  end
  
  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end