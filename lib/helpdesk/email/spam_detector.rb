class Helpdesk::Email::SpamDetector

  include EnvelopeParser
  include Helpdesk::Email::Constants

  def self.fetch_mail(tkt)
    Rails.logger.info "Fetching email from archive path"
    dynamo_obj = Helpdesk::Email::ArchiveDatastore.find(:account_id => tkt.account_id,
     :unique_index => PROCESSED_EMAIL_TYPE[:ticket] + "_" + tkt.id.to_s)
    if dynamo_obj.blank?
      Rails.logger.info "No dynamodb path found"
      return
    end
    archive_db = Helpdesk::DBStore::MailDBStoreFactory.getDBStoreObject(DBTYPE[:archive])
    email_obj = archive_db.fetch(dynamo_obj.path)
    email_obj[:eml].read
  end

  def check_spam(raw_eml, envelope)
    spam_data = {}
    domain = get_domain_from_envelope(envelope)
    Sharding.select_shard_of(domain) do
      account = Account.find_by_full_domain(domain)
      if !account.nil? && account.active? and account.launched?(:spam_detection_service)
        Rails.logger.info "Spam check triggered for the email"
        response = FdSpamDetectionService::Service.new(account.id, raw_eml).check_spam
        Rails.logger.info "Response for spam check: #{response.spam?}"
        Rails.logger.info "Spam Result: #{response.to_param.inspect}"
        spam_data = ticket_spam_info(response)
      end
    end
    spam_data
  rescue ShardNotFound
    return spam_data
  end

  def ticket_spam_info(response)
    { :spam => response.spam?, :rules => response.rules, :score => response.score }.with_indifferent_access
  end

end
