module TrialWidgetConstants
  COMPLETE_STEP_FIELDS = %w[steps goals].freeze
  VALIDATION_CLASS = 'TrialWidgetValidation'.freeze
  SUPPORT_CHANNEL_STEP = 'support_channel'.freeze
  GOALS_AND_STEPS = {
    organiseand_keep_track: {
      custom_name: 'boolean--Goal--Ticket',
      goal_alias_name: 'fdeskgoalticket'
    },
    unify_support_channels: {
      custom_name: 'boolean--Goal--Channel',
      goal_alias_name: 'fdeskgoalchannel'
    },
    automate_repetitive_tasks: {
      custom_name: 'boolean--Goal--Automation',
      goal_alias_name: 'fdeskgoalautomation'
    },
    offer_self_service: {
      custom_name: 'boolean--Goal--Self--Service',
      goal_alias_name: 'fdeskgoalselfservice'
    },
    track_agents_performance: {
      custom_name: 'boolean--Goal--Reports',
      goal_alias_name: 'fdeskgoalreports'
    },
    integrate_with_apps: {
      custom_name: 'boolean--Goal--Integration',
      goal_alias_name: 'fdeskgoalintegration'
    }
  }.freeze
  VALID_STEPS = (Account::SETUP_KEYS | Account::ONBOARDING_V2_GOALS | Account::FRESHMARKETER_EVENTS).freeze
end.freeze
