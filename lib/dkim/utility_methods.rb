module Dkim::UtilityMethods
  def execute_on_master(account_id, record_id)
    ::Account.reset_current_account
    Sharding.select_shard_of(account_id) do
      @account = Account.find_by_id(account_id).make_current
      raise ActiveRecord::RecordNotFound if @account.blank?
      @account.make_current
      @domain_category = @account.outgoing_email_domain_categories.find_by_id(record_id)
      yield
    end
  end
end