class SendgridDomainUpdates

  include Sidekiq::Worker

  TIMEOUT = SendgridWebhookConfig::CONFIG[:timeout]

  sidekiq_options :queue => :sendgrid_domain_updates, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    byebug
    begin 
      unless action.blank?
        domain_in_sendgrid = sendgrid_domain_exists?(args['domain'])
        if (!domain_in_sendgrid && args['action'] == 'delete')
          Rails.logger.info "Domain #{args['domain']} does not exist in sendgrid to delete"
          return
        elsif (domain_in_sendgrid && args['action'] == 'create')
          Rails.logger.info "Domain exists in sendgrid already"
          return
        else
          Timeout::timeout(TIMEOUT) do
            self.send("#{args['action']}_record", args['domain'])
          end
        end
      end
    rescue => e
      FreshdeskErrorsMailer.error_email(nil, {:domain_name => domain}, e, {
        :subject => "Error in updating domain in sendgrid", 
        :recipients => "email-team@freshdesk.com" 
        })
    end
  end

  def sendgrid_domain_exists?(domain)
    Timeout::timeout(TIMEOUT) do
      get_url = SendgridWebhookConfig::SENDGRID_API['get_specific_domain_url'] + domain
      response = HTTParty.get(get_url, :headers => { "Authorization" => "Bearer #{SendgridWebhookConfig::CONFIG['api_key']}"})
      return false unless response.code == 200
    end
    return true
  end

  def delete_record(domain)
    response = HTTParty.delete(SendgridWebhookConfig::SENDGRID_API["delete_url"] + domain, 
      :headers => { "Authorization" => "Bearer #{SendgridWebhookConfig::CONFIG['api_key']}" })
    return false unless response.code == 204
    Rails.logger.info "Deleting domain #{domain} from sendgrid"
    AccountWebhookKeys.destroy_all(account_id: Account.current.id)
  end

  def create_record(domain)
    generated_key = generate_callback_key
    post_url = SendgridWebhookConfig::POST_URL % { :full_domain => domain, :key => generated_key }
    post_args = {:hostname => domain, :url => post_url, :spam_check => true, :send_raw => false }
    response = HTTParty.post(SendgridWebhookConfig::SENDGRID_API["set_url"], 
      :body => post_args.to_json, :headers => { "Authorization" => "Bearer #{SendgridWebhookConfig::CONFIG['api_key']}" })
    return false unless response.code == 200
    verification = AccountWebhookKey.new(:account_id => Account.current.id, 
      :webhook_key => generated_key, :service_id => Account::MAIL_PROVIDER[:sendgrid], :status => 1)
    verification.save!
  end

  def generate_callback_key
    SecureRandom.hex(13)
  end

end