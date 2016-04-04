class PasswordExpiryWorker

  include Sidekiq::Worker
  include Redis::RedisKeys
  include Redis::OthersRedis

  sidekiq_options :queue => 'password_expiry', :retry => 0, :dead => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    return if args[:account_id].blank? || args[:user_type].blank?
    ::Account.reset_current_account
    Sharding.select_shard_of(args[:account_id]) do
      
      account = ::Account.find args[:account_id]
      raise ActiveRecord::RecordNotFound if account.blank?
      account.make_current
      user_type = args[:user_type]
      if (user_type == PasswordPolicy::USER_TYPE[:contact])
        account.users.contacts.active(true).find_each(batch_size: 100) do |customer|
          customer.set_password_expiry({:password_expiry_date => args[:last_date]})
        end
      elsif (user_type == PasswordPolicy::USER_TYPE[:agent])
        account.users.technicians.active(true).find_each(batch_size: 100) do |agent|
          agent.set_password_expiry({:password_expiry_date => args[:last_date]})
        end
      end
      key = password_expiry_key(user_type)
      remove_others_redis_key(key) if redis_key_exists? key
    end
  rescue => e
    Rails.logger.debug "The error is  ::: #{e}"
    NewRelic::Agent.notice_error(e, {:description => "Error while updating password expiry on Account #{args[:account_id]}"})
    raise e
  ensure
    ::Account.reset_current_account
  end

  private
    def password_expiry_key(user_type)
      UPDATE_PASSWORD_EXPIRY % { :account_id => ::Account.current.id, :user_type => user_type }
    end
end
