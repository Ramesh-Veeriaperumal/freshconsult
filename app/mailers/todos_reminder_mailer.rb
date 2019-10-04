class TodosReminderMailer < ActionMailer::Base
  layout 'email_font'

  def send_reminder_email(user, todo_body, ticket, reminder, ticket_url)
    @user_name = user.name
    @todo_content = todo_body
    @ticket = ticket
    @ticket_url = ticket_url
    @reminder_at = reminder
    subject ||= I18n.t('mailer_notifier_subject.send_reminder_email', todo_body: todo_body)
    @headers = {
      from:    Account.current.default_friendly_email,
      to:      user.email,
      subject: subject,
      sent_on: Time.zone.now
    }
    mail(@headers) do |part|
      part.text { render '/helpdesk/todos/email_todos_reminder.text.plain.erb' }
      part.html { render '/helpdesk/todos/email_todos_reminder.text.html.erb' }
    end.deliver
  end
  include MailerDeliverAlias
end
