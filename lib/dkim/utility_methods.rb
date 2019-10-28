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
      Rails.logger.info "Exception while configuring DKIM and Going to Retry::: #{e} ::: retry count #{retried}"
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

  def es_response_success?(email_service_response)
    email_service_response == Dkim::Constants::EMAIL_SERVICE_RESPONSE_CODE[:success]
  end

  def construct_dkim_hash(email_service_domains)
    email_service_domains.inject({}) do |dkim, value|
      dkim[value['domain'].to_sym] = [] | value['records']['dkim']
      dkim[value['domain'].to_sym].push(value['records']['spfmx'])
      dkim
    end
  end
end
