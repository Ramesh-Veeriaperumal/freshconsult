class Email::AccountDetailsDestroyWorker < BaseWorker
  sidekiq_options queue: :email_service_account_details_destroy, retry: 3, backtrace: true, failures: :exhausted
  include Redis::RedisKeys

  class AccountDetailsDestroyError < StandardError
  end

  FD_EMAIL_SERVICE = YAML::load_file(Rails.root.join('config', 'fd_email_service.yml'))[Rails.env]
  TIMEOUT = FD_EMAIL_SERVICE['timeout'].freeze
  URL = FD_EMAIL_SERVICE['account_destroy_urlpath'].freeze
  EMAIL_SERVICE_AUTHORISATION_KEY = FD_EMAIL_SERVICE['key'].freeze
  EMAIL_SERVICE_HOST = FD_EMAIL_SERVICE['host'].freeze

  ERROR_ACCOUNT_DESTROY = 'Email Service account details destroy sidekiq push error'

  def perform(args)
    args.symbolize_keys!
    destroy_account_details_in_email_service args
  rescue Exception => e
    Rails.logger.debug "#{ERROR_ACCOUNT_DESTROY}, #{e.inspect} : #{args.inspect}"
    NewRelic::Agent.notice_error(e, { args: args })
    subject = "Account details not destroyed in email Service  For Account #{args[:account_id]}"
    description = "Account Details are #{args.inspect}"
    FreshdeskErrorsMailer.error_email(nil, args, nil, {
          subject: subject,
          recipients: (Rails.env.development? ? ['saravana.kumar@freshworks.com'] : ['fd-block-alerts@freshworks.com']),
          additional_info: { info: description }
        })
  end

  def destroy_account_details_in_email_service(params)
    con = Faraday.new(EMAIL_SERVICE_HOST) do |faraday|
      faraday.response :json, content_type: /\bjson$/
      faraday.adapter  :net_http_persistent
    end
    response = con.delete do |req|
      req.url URL
      req.headers['Content-Type'] = 'application/json'
      req.headers['Authorization'] = EMAIL_SERVICE_AUTHORISATION_KEY
      req.options.timeout = TIMEOUT
      req.body = params.to_json
    end
    if response.status != 200
      Rails.logger.info "Account Destroy failed at Email service due to : #{response.body['Message']}"
      raise AccountDetailsDestroyError, response.body['Message']
    end
  end
end
