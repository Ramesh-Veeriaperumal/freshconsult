class Admin::BotMailer < ActionMailer::Base
  include EmailHelper

  RECIPIENTS = ['fd-suicide-squad@freshworks.com'].freeze

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

  def bot_training_incomplete_email(bot_id)
    headers = {
      to: RECIPIENTS,
      from: AppConfig['from_email'],
      subject: "#{Rails.env} :: #{PodConfig['CURRENT_POD']} :: Bot Training Incomplete",
      sent_on: Time.zone.now
    }
    mail(headers) do |part|
      part.html { render 'bot_training_incomplete', locals: { account_id: Account.current.id, bot_id: bot_id } }
    end.deliver
  end
end
