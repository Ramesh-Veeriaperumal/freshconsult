module DynamicTemplateHelper
  
  def create_dynamic_notification_template(params)
    template = @account.dynamic_notification_templates.build(
        :language => DynamicNotificationTemplate::LANGUAGE_MAP[params[:language]],
        :category => params[:category] || 1, 
        :active => true, 
        :email_notification_id => params[:email_notification_id],
        :subject => "new #{params[:language]} subject", 
        :description=>"new #{params[:language]} description", 
        :outdated => true
      )
    template.save
    template
  end
end