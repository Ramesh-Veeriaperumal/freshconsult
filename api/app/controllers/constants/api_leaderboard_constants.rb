module ApiLeaderboardConstants
  CATEGORY_LIST = [:mvp, :sharpshooter, :speed].freeze
  LOAD_OBJECT_EXCEPT = [:agents].freeze

  ROOT_KEY = {
    agents: :leaderboard_agents
  }.freeze
end
