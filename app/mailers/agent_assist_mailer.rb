class AgentAssistMailer < ActionMailer::Base
  include EmailHelper

  RECIPIENTS = [FreddySkillsConfig[:agent_assist][:demo_email]].freeze
  SUBJECT = 'Feature Request - Agent Assist'.freeze
  TYPE = 'Request Agent Assist Feature'.freeze

  def request_feature_email
    mail(headers) do |part|
      part.html { render 'request_feature.text.html.erb', options }
    end.deliver
  end

  def headers
    {
      to: RECIPIENTS,
      from: Account.current.admin_email,
      subject: SUBJECT,
      sent_on: Time.zone.now
    }.merge(make_header(nil, nil, Account.current.id, TYPE))
  end

  def options
    {
      locals: {
        account: Account.current,
        freshops_account_url: freshops_account_url(Account.current)
      }
    }
  end
end
