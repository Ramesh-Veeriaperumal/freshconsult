module ScoreboardLevelHelper
  def scoreboard_level_pattern(scoreboard_level, include_points = true)
    return_hash = {
      id: scoreboard_level.id,
      name: scoreboard_level.name
    }
    return_hash[:points] = scoreboard_level.points if include_points
    return_hash
  end
end