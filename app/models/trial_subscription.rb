class TrialSubscription < ActiveRecord::Base
  include FreshdeskFeatures::Feature

  belongs_to_account
  belongs_to :actor, class_name: :User

  concerned_with :constants, :callbacks, :validations

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

  def days_left_for_next_trial
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
end
