class Admin::CustomSurveysMailer < ActionMailer::Base

  helper Admin::CustomSurveysHelper
  layout "email_font"
  include EmailHelper
  
  def preview_email(options={})
    options.symbolize_keys!
    survey = Account.current.custom_surveys.find_by_id(options[:survey_id])
    @user = Account.current.users.find_by_id(options[:user_id])
    email_config = Account.current.primary_email_config
    begin
      configure_email_config email_config

      @survey_handle = CustomSurvey::SurveyHandle.create_handle_for_preview(survey.id, survey.send_while)

      headers = {
        :to      => @user.email,
        :from    => email_config.reply_email,
        :subject => I18n.t('support.tickets.ticket_survey.subject', 
                            :title => survey.title_text),
        :sent_on => Time.now,
        "Reply-to" => "",
        "Auto-Submitted" => "auto-generated", 
        "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
      }

      headers.merge!(make_header(nil, nil, Account.current.id, "Preview Email"))
      headers.merge!({"X-FD-Email-Category" => email_config.category}) if email_config.category.present?
      mail(headers) do |part|
        part.text { render "preview_email.text.plain" }
        part.html { render "preview_email.text.html" }
      end.deliver
    ensure
      remove_email_config
    end
  end 

  # TODO-RAILS3 Can be removed once fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end