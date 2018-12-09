class RemoveEncryptedFieldsWorker
  include Sidekiq::Worker

  sidekiq_options :queue => :remove_encrypted_fields, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform
    @account ||= Account.current
    @account.remove_encrypted_fields
  rescue Exception => e
  	Rails.logger.info "Exception :: RemoveEncryptedFieldsWorker :: while deleting encrypted fields"
  	NewRelic::Agent.notice_error(e, {:description => "Error while deleting encrypted fields"})
  end
end
