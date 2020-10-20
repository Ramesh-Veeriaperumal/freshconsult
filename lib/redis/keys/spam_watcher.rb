module Redis::Keys::SpamWatcher
    SPAM_THRESHOLD            = "SPAM_THRESHOLD:%{account_id}:%{user_id}:%{model}".freeze
    DEFAULT_SPAM_THRESHOLD    = "DEFAULT_SPAM_THRESHOLD:%{state}:%{model}".freeze
    DEFAULT_AGENT_SPAM_THRESHOLD = 'DEFAULT_AGENT_SPAM_THRESHOLD:%{state}:%{model}'.freeze
end