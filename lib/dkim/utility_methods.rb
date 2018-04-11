module Dkim::UtilityMethods
  RETRY_LIMIT = 3
  RETRY_SLEEP_SECONDS = 0.2

  def execute_on_master(account_id, record_id)
    ::Account.reset_current_account
    Sharding.select_shard_of(account_id) do
      @account = Account.find_by_id(account_id)
      raise ActiveRecord::RecordNotFound if @account.blank?
      @account.make_current
      @domain_category = @account.outgoing_email_domain_categories.find_by_id(record_id)
      yield
    end
  end

  def with_retries(*args, &block)
    options = args.extract_options!
    exceptions = args
    options[:limit] ||= RETRY_LIMIT
    options[:sleep] ||= RETRY_SLEEP_SECONDS
    exceptions = [Exception] if exceptions.empty?
    retried = 0
    begin
      yield
    rescue *exceptions => e
      if retried + 1 < options[:limit]
        retried += 1
        sleep options[:sleep].seconds
        options[:sleep] += RETRY_SLEEP_SECONDS
        retry
      else
        raise e
      end
    end
  end
end