class Admin::BotMailer < ActionMailer::Base
  include EmailHelper

  def bot_training_completion_email(bot, to_email, user_name, categories)
    headers = {
      to: to_email,
      from: AppConfig['from_email'],
      subject: I18n.t('bot_training_completed.email.subject'),
      sent_on: Time.now
    }
    headers.merge!(make_header(nil, nil, Account.current.id, 'Bot Training Completion'))
    url = "#{Account.current.url_protocol}://#{Account.current.full_domain}/a/admin/bot/#{bot.id}?tab=test-and-train"
    mail(headers) do |part|
      part.text { render 'bot_training_completed.text.plain.erb', locals: { user_name: user_name, bot_name: bot.name, categories: categories, url: url } }
      part.html { render 'bot_training_completed.text.html.erb', locals: { user_name: user_name, bot_name: bot.name, categories: categories, url: url } }
    end.deliver
  end
end
