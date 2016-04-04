class CRM::Freshsales

  QUEUE = 'salesforceQueue'
  
  class FdAccount
    extend Resque::AroundPerform

    def self.perform(args={})
      account = Account.current
      account_subscription = account.subscription

      subscription = args[:subscription].present? ? prepare_subscription(args[:subscription]) : account_subscription.attributes.symbolize_keys
      cmrr = args[:cmrr].present? ? args[:cmrr].to_f : account_subscription.cmrr

      data = { account: account, subscription: subscription, cmrr: cmrr }
      freshsales = CRM::FreshsalesUtility.new(data)
      handle_data_sync(freshsales, args)
    end

    def self.prepare_subscription(subscription_args)
      subscription_info = subscription_args.symbolize_keys
      subscription_info[:amount] = subscription_info[:amount].to_f
      subscription_info[:created_at] = DateTime.parse(subscription_info[:created_at])
      subscription_info
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

    ACTIVE    = 'active'
    TRIAL     = 'trial'
    SUSPENDED = 'suspended'

    def self.handle_data_sync(freshsales, args)
      begin
        old_subscription = prepare_subscription(args[:old_subscription])
        old_cmrr = args[:old_cmrr].to_f
        payments_count = args[:payments_count].to_i
        subscription = prepare_subscription(args[:subscription])

        case
        when upgrade?(subscription, old_subscription)
          freshsales.account_upgrade(old_cmrr)
        when downgrade?(subscription, old_subscription)
          freshsales.account_downgrade(old_cmrr)
        when trial_expired?(subscription, old_subscription)
          freshsales.account_trial_expiry
        when state_changed?(subscription, old_subscription)
          freshsales.subscription_state_change(old_cmrr, old_subscription[:state].to_sym, payments_count)
        end
      rescue => e
        NewRelic::Agent.notice_error(e, { description: "Error occured while pushing SubscriptionTracking to Freshsales 
          Account:: #{Account.current.id} args:: #{args.inspect}" })
      end
    end

    def self.previously_active?(old_subscription)
      old_subscription[:state].eql?(ACTIVE)
    end

    def self.upgrade?(subscription, old_subscription)
      previously_active?(old_subscription) && (subscription[:amount] > old_subscription[:amount])
    end

    def self.downgrade?(subscription, old_subscription)
      previously_active?(old_subscription) && (subscription[:amount] < old_subscription[:amount]) &&
        additive_changed?(subscription, old_subscription)
    end

    def self.additive_changed?(subscription, old_subscription)
      !old_subscription[:agent_limit].eql?(subscription[:agent_limit]) || 
      !old_subscription[:subscription_plan_id].eql?(subscription[:subscription_plan_id]) ||
      !old_subscription[:renewal_period].eql?(subscription[:renewal_period])
    end

    def self.trial_expired?(subscription, old_subscription)
      (old_subscription[:state] == TRIAL) && (subscription[:state] == SUSPENDED)
    end

    def self.state_changed?(subscription, old_subscription)
      !old_subscription[:state].eql?(subscription[:state])
    end
  end

end