class CRM::Freshsales

  QUEUE = 'salesforceQueue'
  
  class FdAccount
    extend Resque::AroundPerform

    def self.perform(args={})
      return if Rails.env.test?
      
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
        freshsales.push_signup_data(args)
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

  class TrackSubscription < FdAccount
    @queue = QUEUE

    ACTIVE    = 'active'
    TRIAL     = 'trial'
    SUSPENDED = 'suspended'
    FREE      = 'free'

    ZERO      = 0

    def self.handle_data_sync(freshsales, args)
      begin
        old_subscription = prepare_subscription(args[:old_subscription])
        subscription = prepare_subscription(args[:subscription])       
        old_cmrr = args[:old_cmrr].to_f
        cmrr = args[:cmrr].to_f
        payments_count = args[:payments_count].to_i
        is_state_changed = state_changed?(subscription, old_subscription)

        case
        when opted_for_free_plan?(subscription, old_subscription, cmrr, payments_count)
          amount = ZERO
          freshsales.push_subscription_changes(:new_business, amount, payments_count, is_state_changed)

        when paid_activation?(subscription, old_subscription)
          amount = cmrr.round(2)
          deal_type = paid_customer?(payments_count) ? :upgrade : :new_business
          freshsales.push_subscription_changes(deal_type, amount, payments_count, is_state_changed)

        when upgrade?(subscription, old_subscription)
          amount = calculate_deal_amount(cmrr, old_cmrr)
          freshsales.push_subscription_changes(:upgrade, amount, payments_count, is_state_changed)

        when downgrade?(subscription, old_subscription)
          amount = calculate_deal_amount(cmrr, old_cmrr)
          freshsales.push_subscription_changes(:downgrade, amount, payments_count, is_state_changed)

        when trial_expired?(subscription, old_subscription)
          freshsales.account_trial_expiry

        when trial_extended?(subscription, old_subscription)
          freshsales.account_trial_extension

        when is_state_changed
          (deal_type, amount) = get_deal_type_and_amount(subscription, old_subscription, cmrr, old_cmrr, payments_count)
          freshsales.push_subscription_changes(deal_type, amount, payments_count, is_state_changed) if(deal_type.present? && amount.present?)
        end
      rescue => e
        NewRelic::Agent.notice_error(e, { description: "Error occured while pushing SubscriptionTracking to Freshsales 
          Account:: #{Account.current.id} args:: #{args.inspect}" })
      end
    end

    def self.previously_active?(old_subscription)
      old_subscription[:state].eql?(ACTIVE)
    end

    def self.amount_increased_from_zero?(subscription, old_subscription)
      (old_subscription[:amount] == ZERO) && (subscription[:amount] > ZERO)
    end

    # Will pass when, Account moves from "Trial->Active", "Free->Active" 
    #   for both Existing and Newly Paying Accounts
    def self.paid_activation?(subscription, old_subscription)
      ((!previously_active?(old_subscription) && subscription[:amount] > ZERO) || (amount_increased_from_zero?(subscription, old_subscription))) && subscription[:state].eql?(ACTIVE)
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

    def self.trial_extended?(subscription, old_subscription)
      (old_subscription[:state] == SUSPENDED) && (subscription[:state] == TRIAL)
    end

    def self.state_changed?(subscription, old_subscription)
      !old_subscription[:state].eql?(subscription[:state])
    end

    def self.get_deal_type_and_amount(subscription, old_subscription, cmrr, old_cmrr, payments_count)
      old_state = old_subscription[:state]
      current_state = subscription[:state]

      (deal_type, amount) = case
                            when reactivation?(old_state, current_state, payments_count)
                              [:upgrade, cmrr.round(2)]
                            when (old_state == ACTIVE && current_state == SUSPENDED)
                              amount = (subscription[:amount] == ZERO) ? calculate_deal_amount(cmrr, old_cmrr) : 
                                                                          -cmrr.round(2)
                              [:downgrade, amount]
                            else
                              [nil, nil]
                            end
    end

    def self.calculate_deal_amount(cmrr, old_cmrr)
      (cmrr - old_cmrr).round(2)
    end

    def self.opted_for_free_plan?(subscription, old_subscription, cmrr, payments_count)
      old_state = old_subscription[:state]
      current_state = subscription[:state]

      !old_state.eql?(FREE) && free_plan_selected?(current_state, cmrr) && !paid_customer?(payments_count)
    end

    def self.free_plan_selected?(current_state, cmrr)
      current_state == FREE || (current_state == ACTIVE && cmrr == ZERO)
    end

    def self.paid_customer?(payments_count)
      payments_count > ZERO
    end
    
    def self.reactivation?(old_state, current_state, payments_count)
      paid_customer?(payments_count) && [TRIAL, SUSPENDED].include?(old_state) && (current_state == ACTIVE)
    end
  end

end