class TrialSubscription < ActiveRecord::Base
  after_commit -> { change_trial_subscription(:cancel) }, on: :update,
                                                          if: :trigger_feature_downgrade?
  after_commit -> { 
    change_trial_subscription(:activate) 
    push_data_to_autopilot(:activate)
  }, on: :create, if: :active?

  after_commit -> { push_data_to_autopilot(:cancel) }, on: :update, 
    if: :cancelling_the_trial?

  private

    def status_changed_result_plan?
      previous_changes.key?(:status) && result_plan.nil?
    end

    def trigger_feature_downgrade?
      (status == TRIAL_STATUSES[:inactive] ||
        status == TRIAL_STATUSES[:cancelled] ) &&
          status_changed_result_plan?
    end

    def change_trial_subscription(action_type)
      account = Account.current
      ACTION_TO_PLAN_CHANGE_CLASS[action_type].new(account, self).execute
    rescue StandardError => e
      NewRelic::Agent.notice_error(e, description: "Trial subscriptions : #{account.id} :
          Error while initializing : trying to #{action_type}")
      Rails.logger.error "Trial subscriptions : #{account.id} : Error while
          initializing : trying to #{action_type} : #{e.inspect} #{e.backtrace.join("\n\t")}"
    end

    def push_data_to_autopilot(action_type)
      Subscriptions::UpdateLeadToAutopilot.perform_async({
        email: self.actor.email,
        event: ThirdCRM::EVENTS[:trial_subscription],
        action_type: action_type,
        plan: self.trial_plan,
        name: self.actor.name
      })
    end

    def cancelling_the_trial?
      previous_changes.key?(:status) && (status == TRIAL_STATUSES[:inactive] ||
        status == TRIAL_STATUSES[:cancelled])
    end
end
