class RemoveEncryptedFieldsWorker
  include Sidekiq::Worker
  include Cache::Memcache::CompanyField
  include Cache::Memcache::ContactField

  sidekiq_options :queue => :remove_encrypted_fields, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform
    @account ||= Account.current
    @account.remove_encrypted_fields
    clear_contact_fields_cache
    clear_company_fields_cache
  rescue Exception => e
  	Rails.logger.info "Exception :: RemoveEncryptedFieldsWorker :: while deleting encrypted fields"
  	NewRelic::Agent.notice_error(e, {:description => "Error while deleting encrypted fields"})
  end
end
