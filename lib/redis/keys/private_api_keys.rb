module Redis::Keys::PrivateApiKeys
  DATA_VERSIONING_SET = "DATA_VERSIONING_SET:%{account_id}".freeze
  
  def version_key
    @version_key ||= DATA_VERSIONING_SET % {account_id: Account.current.id}
  end
end
