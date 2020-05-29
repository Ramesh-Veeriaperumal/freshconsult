module Admin::FreddyConstants
  FREDDY_SKILLS_ELIGIBILITY = {
    detect_thank_you_note: :detect_thank_you_note_eligible,
    ticket_properties_suggester: :ticket_properties_suggester_eligible,
    agent_articles_suggest: :agent_articles_suggest_eligible
  }.freeze

  CALLBACKS = {
    detect_thank_you_note: {
      enable: :configure_thank_you_redis_key,
      disable: :remove_thank_you_redis_key
    },
    agent_articles_suggest: {
      enable: :create_agent_articles_suggest_bot,
      disable: :create_agent_articles_suggest_bot
    }
  }.freeze
end
