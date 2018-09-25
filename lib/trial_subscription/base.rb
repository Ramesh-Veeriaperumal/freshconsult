class TrialSubscription::Base < SAAS::SubscriptionEventActions

  DROP_DATA_FEATURES = (SAAS::SubscriptionActions::DROP_DATA_FEATURES +
    DROP_DATA_FEATURES_V2).uniq.freeze

  ADD_DATA_FEATURES  = (SAAS::SubscriptionActions::ADD_DATA_FEATURES + 
    ADD_DATA_FEATURES_V2).uniq.freeze

  attr_accessor :trial_subscription

  delegate :trial_plan, :features_list, to: :trial_subscription

  def initialize(account, trial_subscription)
    @trial_subscription = trial_subscription
    super(account)
  end

  def execute
    self.change_plan
  rescue StandardError => e
    NewRelic::Agent.notice_error(e, {
      description: "Trial subscriptions : #{account.id} : Error while trying 
        to #{self.class.name}",
      account_id: account.id,
      features_list: trial_subscription.features_list
    })
    Rails.logger.error "Trial subscriptions : #{account.id} : Error while 
      trying to #{self.class.name} : #{e.inspect} #{e.backtrace.join("\n\t")}"
  end

  private

    def add_ons_changed?
      false
    end

    def plan_changed?
      true
    end
end