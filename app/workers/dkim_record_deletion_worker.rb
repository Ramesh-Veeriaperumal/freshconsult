class DkimRecordDeletionWorker

  include Sidekiq::Worker
  include Dkim::UtilityMethods

  sidekiq_options :queue => :dkim_general, :retry => 5, :failures => :exhausted
  
  sidekiq_retry_in do |count|
    (count+5).minutes
  end
  
  sidekiq_retries_exhausted do |msg|
    Sidekiq.logger.warn "Failed #{msg['class']} with #{msg['args']}: #{msg['error_message']}"
    Dkim::UserNotification.new.notify_dev(msg)
  end

  def perform(args)
    args.symbolize_keys!
    return if args[:domain_id].blank?
    execute_on_master(args[:account_id], args[:domain_id]){
      if Account.current.launched?(:dkim_email_service)
        Dkim::RemoveDkim.new(@domain_category).remove if @domain_category.present? and @domain_category.status == OutgoingEmailDomainCategory::STATUS['delete']
      else
        Dkim::RemoveDkimConfig.new(@domain_category).remove_records if @domain_category.present? and @domain_category.status == OutgoingEmailDomainCategory::STATUS['delete']
      end
    }
  end
end 
