class Search::CreateAlias
  extend Resque::AroundPerform
  @queue = 'es_alias_queue'

  def self.perform(args)
    args.symbolize_keys!
    account = Account.current
    account.create_es_enabled_account(:account_id => args[:account_id])
  end
end