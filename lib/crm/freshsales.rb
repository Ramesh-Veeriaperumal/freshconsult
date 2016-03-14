class CRM::Freshsales

  QUEUE = 'salesforceQueue'
  
  class FdAccount
    extend Resque::AroundPerform
    def self.perform(args={})
      account = Account.current
      freshsales = CRM::FreshsalesUtility.new(account)

      handle_data_sync(freshsales, args)
    end
  end

  class Signup < FdAccount
    @queue = QUEUE

    def self.handle_data_sync(freshsales, args)
      begin
        freshsales.push_signup_data
      rescue => e
        NewRelic::Agent.notice_error(e, { description: "Error occured while pushing Signup data to Freshsales 
          AccountID::#{Account.current.id}" })
      end
    end
  end

  class AdminUpdate < FdAccount
    @queue = QUEUE

    def self.handle_data_sync(freshsales, args)
      begin
        freshsales.update_admin_info
      rescue => e
        NewRelic::Agent.notice_error(e, { description: "Error occured while pushing AdminUpdate Info to Freshsales 
          AccountID::#{Account.current.id}" })
      end
    end
  end

  class AccountActivation < FdAccount
    @queue = QUEUE

    def self.handle_data_sync(freshsales, args)
      begin
        freshsales.account_activation(args)
      rescue => e
        NewRelic::Agent.notice_error(e, { description: "Error occured while pushing AccountActivation Info to Freshsales 
          AccountID::#{Account.current.id}" })
      end
    end
  end

  class TrackSubscription < FdAccount
    @queue = QUEUE

    include Subscription::Events::AssignEventCode

    def self.handle_data_sync(freshsales, args)
      begin
        args[:old_subscription].symbolize_keys!

        subscription = Subscription.find_by_account_id_and_id(Account.current.id, args[:subscription_id])
        old_subscription = prepare_old_subscription(args[:old_subscription])
  
        case
        when upgrade?(subscription, old_subscription)
          freshsales.account_upgrade(old_subscription)
        when downgrade?(subscription, old_subscription)
          freshsales.account_downgrade(old_subscription)
        when state_changed?(subscription, old_subscription)
          freshsales.update_customer_status(old_subscription)
        end
      rescue => e
        NewRelic::Agent.notice_error(e, { description: "Error occured while pushing SubscriptionTracking to Freshsales 
          Account:: #{Account.current.id} args:: #{args.inspect}" })
      end
    end

    def self.state_changed?(subscription, old_subscription)
      !old_subscription[:state].eql?(subscription.state)
    end

    def self.prepare_old_subscription(old_subscription_args)
      old_subscription_args[:amount] = old_subscription_args[:amount].to_f
      old_subscription_args
    end
  end

end