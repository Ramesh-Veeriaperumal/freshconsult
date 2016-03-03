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

    TRACK_FIELDS = [:amount, :state, :agent_limit, :subscription_plan_id, :renewal_period]

    def self.handle_data_sync(freshsales, args)
      begin
        args[:previous_changes].symbolize_keys!

        subscription = Subscription.find_by_account_id_and_id(Account.current.id, args[:subscription_id])
        old_subscription = prepare_old_subscription(subscription, args[:previous_changes])
  
        case
        when (upgrade?(subscription, old_subscription) && !trial_or_free_to_active?(subscription))
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

    def self.trial_or_free_to_active?(subscription)
      subscription.subscription_payments.count == 0
    end

    def self.state_changed?(subscription, old_subscription)
      !old_subscription[:state].eql?(subscription.state)
    end

    def self.prepare_old_subscription(subscription, previous_changes)
      old_subscription = TRACK_FIELDS.inject({}) { |hash, field|
            hash.merge({ field => previous_changes[field].try(:first) || subscription.send(field) })}

      old_subscription[:amount] = old_subscription[:amount].to_f if old_subscription
      old_subscription
    end
  end

end