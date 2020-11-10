class Helpdesk::Email::SpamDetector

  include EnvelopeParser
  include Helpdesk::Email::Constants

  def self.fetch_mail(tkt)
    Rails.logger.info "Fetching email from archive path"
    dynamo_obj = Helpdesk::Email::ArchiveDatastore.find(:account_id => tkt.account_id,
     :unique_index => PROCESSED_EMAIL_TYPE[:ticket] + "_" + tkt.id.to_s)
    if dynamo_obj.blank? or dynamo_obj.path.blank?
      Rails.logger.info "No dynamodb path found"
      return
    end
    archive_db = Helpdesk::DBStore::MailDBStoreFactory.getDBStoreObject(DBTYPE[:archive])
    email_obj = archive_db.fetch(dynamo_obj.path)
    raw_eml = email_obj[:eml].read
    mail = process_mail(raw_eml)
    return mail
  rescue Helpdesk::Email::Errors::EmailDBRecordNotFound
    Rails.logger.info "S3 key not found"
  end

  def self.process_mail(raw_eml)
    params = Helpdesk::EmailParser::EmailProcessor.new(raw_eml).process_mail
    construct_raw_mail(params)
  end

  def check_spam(params, envelope)
    spam_data = {}
    domain = get_domain_from_envelope(envelope)
    Sharding.select_shard_of(domain) do
      account = Account.find_by_full_domain(domain)
      if account
        raw_eml = self.class.construct_raw_mail(params)
        Rails.logger.info "Spam check triggered for the email"
        response = FdSpamDetectionService::Service.new(account.id, raw_eml).check_spam
        Rails.logger.info "Response for spam check: #{response.spam?} : Account Info: #{account.id}"
        Rails.logger.info "Spam Result: #{response.to_param.inspect} : Account Info: #{account.id}"
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

  def self.construct_raw_mail(params)
    html_content, plain_content = truncate_large_mail(params)
    mail = Mail.new
    if params[:headers].present?
      mail.header params[:headers]
    elsif params[:from].present?
      mail.from params[:from]
      mail.to   params[:to]
    end
    mail.text_part do 
      body plain_content
    end
    mail.html_part do
      body html_content
    end
    mail.message_id params[:message_id] if params[:message_id].present?
    mail.to_s
  end

  def self.truncate_large_mail(params)
    processed = []
    TRUNCATE_CONTENT.each do |key|
      processed << params[key].truncate(TRUNCATE_SIZE, omission: '') if params[key].present?
      Rails.logger.info "Truncating the #{key} content since length exceeds limit #{TRUNCATE_SIZE} bytes" if params[key].present? and params[key].bytesize > TRUNCATE_SIZE
    end
    return processed
  end

end
