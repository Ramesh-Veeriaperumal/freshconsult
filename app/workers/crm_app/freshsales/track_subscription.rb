class CRMApp::Freshsales::TrackSubscription < CRMApp::Freshsales::BaseWorker

  ACTIVE    = 'active'
  TRIAL     = 'trial'
  SUSPENDED = 'suspended'
  FREE      = 'free'
  ZERO      = 0

  def perform(args = {})
    args.symbolize_keys!
    execute_on_shard(args[:account_id]){
      freshsales_utility = freshsales_utility(args, Account.current)
      old_subscription = prepare_subscription(args[:old_subscription])
      subscription = prepare_subscription(args[:subscription])       
      old_cmrr = args[:old_cmrr].to_f
      cmrr = args[:cmrr].to_f
      payments_count = args[:payments_count].to_i
      is_state_changed = state_changed?(subscription, old_subscription)

      case
      when opted_for_free_plan?(subscription, old_subscription, cmrr, payments_count)
        amount = ZERO
        freshsales_utility.push_subscription_changes(:free, amount, payments_count, is_state_changed)

      when paid_activation?(subscription, old_subscription)
        amount = cmrr.round(2)
        deal_type = paid_customer?(payments_count) ? :upgrade : :new_business
        freshsales_utility.push_subscription_changes(deal_type, amount, payments_count, is_state_changed)

      when upgrade?(subscription, old_subscription)
        amount = calculate_deal_amount(cmrr, old_cmrr)
        freshsales_utility.push_subscription_changes(:upgrade, amount, payments_count, is_state_changed)

      when downgrade?(subscription, old_subscription)
        amount = calculate_deal_amount(cmrr, old_cmrr)
        freshsales_utility.push_subscription_changes(:downgrade, amount, payments_count, is_state_changed)

      when trial_expired?(subscription, old_subscription)
        freshsales_utility.account_trial_expiry

      when trial_extended?(subscription, old_subscription)
        freshsales_utility.account_trial_extension

      when is_state_changed
        (deal_type, amount) = get_deal_type_and_amount(subscription, old_subscription, cmrr, old_cmrr, payments_count)
        freshsales_utility.push_subscription_changes(deal_type, amount, payments_count, is_state_changed) if(deal_type.present? && amount.present?)
      end
    }
  rescue ShardNotFound => e
    Rails.logger.error "ShardNotFound exception while pushing Subscription
    Info to Freshsales args::#{args.inspect} : #{e.message} - #{e.backtrace}"
  rescue => e
    Rails.logger.error "Error occured while pushing SubscriptionTracking to 
      Freshsales, args:: #{args.inspect},\n #{e.message} - #{e.backtrace}" 
    NewRelic::Agent.notice_error(e, { description: "Error occured while pushing 
      SubscriptionTracking to Freshsales args:: #{args.inspect}" })
  end

  private

  def previously_active?(old_subscription)
    old_subscription[:state].eql?(ACTIVE)
  end

  def amount_increased_from_zero?(subscription, old_subscription)
    (old_subscription[:amount] == ZERO) && (subscription[:amount] > ZERO)
  end

  # Will pass when, Account moves from "Trial->Active", "Free->Active" 
  #   for both Existing and Newly Paying Accounts
  def paid_activation?(subscription, old_subscription)
    ((!previously_active?(old_subscription) && subscription[:amount] > ZERO) || 
      (amount_increased_from_zero?(subscription, old_subscription))) && 
      subscription[:state].eql?(ACTIVE)
  end

  def upgrade?(subscription, old_subscription)
    previously_active?(old_subscription) && (subscription[:amount] > 
      old_subscription[:amount])
  end

  def downgrade?(subscription, old_subscription)
    previously_active?(old_subscription) && (subscription[:amount] < 
      old_subscription[:amount]) && additive_changed?(subscription, old_subscription)
  end

  def additive_changed?(subscription, old_subscription)
    !old_subscription[:agent_limit].eql?(subscription[:agent_limit]) || 
    !old_subscription[:subscription_plan_id].eql?(subscription[:subscription_plan_id]) ||
    !old_subscription[:renewal_period].eql?(subscription[:renewal_period])
  end

  def trial_expired?(subscription, old_subscription)
    (old_subscription[:state] == TRIAL) && (subscription[:state] == SUSPENDED)
  end

  def trial_extended?(subscription, old_subscription)
    (old_subscription[:state] == SUSPENDED) && (subscription[:state] == TRIAL)
  end

  def state_changed?(subscription, old_subscription)
    !old_subscription[:state].eql?(subscription[:state])
  end

  def get_deal_type_and_amount(subscription, old_subscription, cmrr, old_cmrr, payments_count)
    old_state = old_subscription[:state]
    current_state = subscription[:state]

    (deal_type, amount) = case
                          when reactivation?(old_state, current_state, payments_count)
                            [:upgrade, cmrr.round(2)]
                          when (old_state == ACTIVE && current_state == SUSPENDED)
                            amount = (subscription[:amount] == ZERO) ? 
                                        calculate_deal_amount(cmrr, old_cmrr) : 
                                        -cmrr.round(2)
                            [:downgrade, amount]
                          else
                            [nil, nil]
                          end
  end

  def calculate_deal_amount(cmrr, old_cmrr)
    (cmrr - old_cmrr).round(2)
  end

  def opted_for_free_plan?(subscription, old_subscription, cmrr, payments_count)
    old_state = old_subscription[:state]
    current_state = subscription[:state]

    !old_state.eql?(FREE) && free_plan_selected?(current_state, cmrr) && !paid_customer?(payments_count)
  end

  def free_plan_selected?(current_state, cmrr)
    current_state == FREE || (current_state == ACTIVE && cmrr == ZERO)
  end

  def paid_customer?(payments_count)
    payments_count > ZERO
  end
  
  def reactivation?(old_state, current_state, payments_count)
    paid_customer?(payments_count) && [TRIAL, SUSPENDED].include?(old_state) && (current_state == ACTIVE)
  end

end