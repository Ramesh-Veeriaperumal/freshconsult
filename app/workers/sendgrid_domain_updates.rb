class SendgridDomainUpdates < BaseWorker

  TIMEOUT = SendgridWebhookConfig::CONFIG[:timeout]

  sidekiq_options :queue => :sendgrid_domain_updates, :retry => 3, :backtrace => true, :failures => :exhausted

  def perform(args)
    begin 
      unless args['action'].blank?
        domain_in_sendgrid = sendgrid_domain_exists?(args['domain'])
        if (!domain_in_sendgrid && args['action'] == 'delete')
          Rails.logger.info "Domain #{args['domain']} does not exist in sendgrid to delete"
        elsif (domain_in_sendgrid && args['action'] == 'create')
          notify_and_update(args['domain'], args['vendor_id'])
        elsif (args['action'] == 'create' or args['action'] == 'delete')
          self.send("#{args['action']}_record", args['domain'], args['vendor_id'])
        end
      end
    rescue => e
      FreshdeskErrorsMailer.error_email(nil, {:domain_name => args['domain']}, e, {
        :subject => "Error in updating domain in sendgrid", 
        :recipients => "email-team@freshdesk.com" 
        })
    end
  end

  def sendgrid_domain_exists?(domain)
    response = send_request('get', SendgridWebhookConfig::SENDGRID_API['get_specific_domain_url'] + domain)
    return true if response.code == 200
  end

  def delete_record(domain, vendor_id)
    response = send_request('delete', SendgridWebhookConfig::SENDGRID_API["delete_url"] + domain)
    return false unless response.code == 204
    Rails.logger.info "Deleting domain #{domain} from sendgrid"
    AccountWebhookKeys.destroy_all(account_id: Account.current.id, vendor_id: vendor_id)
  end

  def create_record(domain, vendor_id)
    generated_key = generate_callback_key
    post_url = SendgridWebhookConfig::POST_URL % { :full_domain => domain, :key => generated_key }
    post_args = {:hostname => domain, :url => post_url, :spam_check => true, :send_raw => false }
    response = send_request('post', SendgridWebhookConfig::SENDGRID_API["set_url"] + , post_args)
    return false unless response.code == 200
    verification = AccountWebhookKey.new(:account_id => Account.current.id, 
      :webhook_key => generated_key, :vendor_id => vendor_id, :status => 1)
    verification.save!
  end

  def notify_and_update(domain, vendor_id)
    FreshdeskErrorsMailer.error_email(nil, {:domain_name => domain}, nil, {
      :subject => "Error in creating mapping for a domain in sendgrid", 
      :recipients => "email-team@freshdesk.com",
      :additional_info => "Domain already exists in sendgrid"
      })

    generated_key = generate_callback_key
    post_url = SendgridWebhookConfig::POST_URL % { :full_domain => domain, :key => generated_key }
    post_args = { :url => post_url, :spam_check => true, :send_raw => false }
    response = send_request('patch', SendgridWebhookConfig::SENDGRID_API['update_url'] + domain, post_args)
    AccountWebhookKey.find_by_account_id_and_vendor_id(Account.current.id, vendor_id).update_attributes(:webhook_key => generated_key)
  end

  def send_request(action, url, post_args={})
    Timeout::timeout(TIMEOUT) do
      response = HTTParty.send(action, url, :body => post_args.to_json, 
        :headers => { "Authorization" => "Bearer #{SendgridWebhookConfig::CONFIG['api_key']}" })
    end
  end

  def generate_callback_key
    SecureRandom.hex(13)
  end

end
