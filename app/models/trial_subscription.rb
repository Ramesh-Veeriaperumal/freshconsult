class TrialSubscription < ActiveRecord::Base
  include FreshdeskFeatures::Feature
  include Redis::RateLimitRedis

  belongs_to_account
  belongs_to :actor, class_name: :User

  concerned_with :constants, :callbacks, :validations

  after_commit :clear_cache

  scope :trials_by_status, -> (s) { where(status: TRIAL_STATUSES[s.to_sym]) }
  scope :ending_trials, -> (date, status) { where('ends_at <= ?', date).trials_by_status(status) }
  before_create :remove_scheduled_requests, if: -> { account.downgrade_policy_enabled? }

  def construct_and_save
    self.from_plan     = account.subscription.subscription_plan.name
    self.actor         = User.current
    self.status        = TrialSubscription::TRIAL_STATUSES[:active]
    self.ends_at       = Time.now.end_of_day.utc + TRIAL_PERIOD_LENGTH.days
    generate_features_diff(trial_plan)
    save
  end

  def mark_cancelled!
    self.status = TrialSubscription::TRIAL_STATUSES[:cancelled]
    self.ends_at = Time.now.utc
    save
  end

  def active?
    status == TRIAL_STATUSES[:active]
  end

  def generate_features_diff(trial_plan)
    existing_features = (account.features_list + account.addons.collect(&:features).flatten).uniq
    # for features which  aren't there, set the bit flag.
    reset_features_bit(plan_features(trial_plan) - existing_features)
  end

  def column_name_lookup(_feature)
    :features_diff
  end

  def days_left_until_next_trial
    return if active?
    interval = TRIAL_INTERVAL_IN_DAYS - (Time.now.utc.to_datetime -
      ends_at.to_datetime).to_i
    interval < 0 ? 0 : interval
  end

  def feature_bitmap(feature)
    FEATURES_DATA[:plan_features][:feature_list][feature]
  rescue StandardError
    Rails.logger.info "Feature not available in yml:: #{feature}"
  end

  def update_result!(old_subscription, new_subscription)
    if old_subscription.subscription_plan_id != new_subscription.subscription_plan_id
      self.result_plan = new_subscription.subscription_plan.name
      self.result = calculate_result(old_subscription.subscription_plan, new_subscription.subscription_plan)
      self.status = TrialSubscription::TRIAL_STATUSES[:inactive]
      self.ends_at = Time.now.utc
    else
      self.result = TrialSubscription::RESULTS[:addons_changed]
    end
    save!
  rescue StandardError => e
    NewRelic::Agent.notice_error(e, description: "Trial subscriptions : #{Account.current.id} :
          Error during subscription change or addon change")
    Rails.logger.error "Trial subscriptions : #{Account.current.id} : Error during subscription change or addon change : #{e.inspect} #{e.backtrace.join("\n\t")}"
  end

  def days_left
    (ends_at.utc.to_datetime - Time.now.utc.to_datetime).to_i if active?
  end

  def extend_trial(days_count)
    self.ends_at = days_count.days.from_now.end_of_day
    set_redis_expiry(account_api_limit_key, self.ends_at.to_i - Time.now.to_i) if get_redis_api_expiry(account_api_limit_key) > 0
    save!
  rescue StandardError => e
    Rails.logger.error "Exception while extending higher plan trial, acc: #{account_id}"
    raise e
  end

  def change_trial_plan(new_trial_plan)
    actual_features_list = account.features_list - features_list
    reset_features_bit(plan_features(new_trial_plan) - actual_features_list)
    self.trial_plan = new_trial_plan
    save!
    TrialSubscriptionActions::PlanUpgrade.new(account, self).execute
  rescue StandardError => e
    Rails.logger.error "Exception while changing trial plan, acc: #{account_id}\
    new trial plan: #{new_trial_plan}, error message: #{e.message}"
    raise e
  end

  private

    def reset_features_bit(features)
      # clear all features of trial subscription features diff
      self.features_diff = '0'
      features.each do |feature|
        set_feature feature
      end
    end

    def plan_features(trial_plan)
      ::PLANS[:subscription_plans][
        SubscriptionPlan::SUBSCRIPTION_PLANS.key(trial_plan)][:features].dup
    end

    def calculate_result(old_plan, new_plan)
      old_plan.amount > new_plan.amount ? TrialSubscription::RESULTS[:downgraded] : TrialSubscription::RESULTS[:upgraded]
    end
  
    def clear_cache
      key = MemcacheKeys::TRIAL_SUBSCRIPTION % { :account_id => self.account_id }
      MemcacheKeys.delete_from_cache key
    end

    def account_api_limit_key
      ACCOUNT_API_LIMIT % { account_id: Account.current.id }
    end

    def remove_scheduled_requests
      if account.subscription.subscription_request.present?
        (errors[:base] << :subscription_request_destroy_error; return false) unless account.subscription.subscription_request.destroy
      elsif account.account_cancellation_requested?
        (errors[:base] << :account_cancellation_destroy_error; return false) unless account.kill_scheduled_account_cancellation
      end
      true
    end
end
