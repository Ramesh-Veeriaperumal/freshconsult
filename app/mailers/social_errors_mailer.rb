class SocialErrorsMailer < ActionMailer::Base

  layout "email_font"

  RECIPIENTS = ['fd-social-team@freshworks.com', 'krishnanand.balasubramanian@freshworks.com'].freeze


  def threshold_reached(options={})
    headers = {
      :to        => RECIPIENTS,
      :from      => "rachel@freshdesk.com",
      :subject   =>  "Critical Error - Threshold reached in SQS",
      :sent_on   => Time.now
    }
    @params = options
    mail(headers) do |part|
      part.html { render "threshold_reached", :formats => [:html] }
    end.deliver
  end

  def facebook_exception(options, params = nil, subject = nil)
    headers = {
      to: RECIPIENTS,
      from: 'rachel@freshdesk.com',
      subject: subject || 'Critical Error - Facebook Exception',
      sent_on: Time.zone.now
    }
    @error = options
    @params = params
    mail(headers) do |part|
      part.html { render 'facebook_exception', formats: [:html] }
    end.deliver
  rescue StandardError => e
    Rails.logger.error "Exception while delivering facebook exception #{subject} #{params.inspect} via mail #{e.message}"
  end

  def twitter_exception(options, params = nil, subject = nil)
    headers = {
      to: RECIPIENTS,
      from: 'rachel@freshdesk.com',
      subject: subject || 'Critical Error - Twitter Exception',
      sent_on: Time.zone.now,
      body: params
    }
    @error = options
    @params = params

    mail(headers) do |part|
      part.html { render 'twitter_exception', formats: [:html] }
    end.deliver
  rescue StandardError => e
    Rails.logger.error "Exception while delivering twitter exception #{subject} #{params.inspect} via mail #{e.message}"
  end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end
