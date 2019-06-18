class Users::UpdateLanguage < BaseWorker
  sidekiq_options queue: :update_user_language,
                  retry: 0,
                  failures: :exhausted

  BATCH_LIMIT = 500

  def perform(args)
    begin
      args.symbolize_keys!
      account = Account.current
      acc_language = account.language

      account.all_users.where("language != ?", acc_language).select(:id).find_in_batches(batch_size: BATCH_LIMIT) do |users|
        user_ids = users.map(&:id)
        account.all_users.where(id: user_ids).update_all_without_batching({ language: acc_language })
      end

      # account.all_users.where("language != ?", account.language).update_all_with_publish({ language: account.language })

    rescue Exception => e
        puts e.inspect, args.inspect
        NewRelic::Agent.notice_error(e, {:args => args})
        raise e
    end
  end
end