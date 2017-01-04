class Dkim::UserNotification
  include Dkim::UtilityMethods
  include Dkim::Methods
  
  def notify_user(args)
    args.symbolize_keys!
    execute_on_master(args[:account_id], args[:record_id]){   
      if redis_key_exists?(dkim_verify_key(@domain_category))
        remove_others_redis_key(dkim_verify_key(@domain_category))
        UserNotifier.notify_dkim_failure(Account.current, @domain_category.attributes)
      end
    }
  end
  
  def notify_dev(msg)
    UserNotifier.notify_dev_dkim_failure({'class' => msg['class'], 'args' => msg['args'],
       'err_msg' => msg['error_message']})
  end
  
end