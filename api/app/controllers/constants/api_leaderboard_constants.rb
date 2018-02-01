module ApiLeaderboardConstants
  CATEGORY_LIST = [:mvp, :sharpshooter, :speed].freeze
  LOAD_OBJECT_EXCEPT = [:agents, :groups].freeze

  ROOT_KEY = {
    agents: :leaderboard_agents,
    groups: :leaderboard_groups
  }.freeze

  LEADERBOARD_AGENTS_FIELDS = [:mini_list, :group_id, :date_range, :date_range_selected].freeze

  LEADERBOARD_GROUPS_FIELDS = [:date_range, :date_range_selected].freeze

  DATE_RANGE_OPTIONS = ['select_range', '3_months_ago', '2_months_ago', 'last_month', 'current_month'].freeze
end
