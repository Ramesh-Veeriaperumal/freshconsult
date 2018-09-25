class TrialSubscription < ActiveRecord::Base
  include FreshdeskFeatures::Feature

  belongs_to_account
  belongs_to :actor, class_name: :User

  concerned_with :constants, :callbacks, :validations

  after_commit :clear_cache
  scope :trials_by_status, ->(s) { where(status: TRIAL_STATUSES[s.to_sym]) }
  scope :ending_trials, ->(date, status) { where('ends_at <= ?', date).trials_by_status(status) }

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
    self.features_diff = '0' # clear all features of trial subscription features diff
    existing_features = (account.features_list + account.addons.collect(&:features).flatten).uniq
    new_features = ::PLANS[:subscription_plans][SubscriptionPlan::SUBSCRIPTION_PLANS.key(trial_plan)][:features].dup
    # for features which  aren't there, set the bit flag.
    (new_features - existing_features).each do |f|
      set_feature f
    end
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

  private

    def calculate_result(old_plan, new_plan)
      old_plan.amount > new_plan.amount ? TrialSubscription::RESULTS[:downgraded] : TrialSubscription::RESULTS[:upgraded]
    end
  
    def clear_cache
      key = MemcacheKeys::TRIAL_SUBSCRIPTION % { :account_id => self.account_id }
      MemcacheKeys.delete_from_cache key
    end
end
