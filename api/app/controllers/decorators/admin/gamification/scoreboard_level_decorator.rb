class Admin::Gamification::ScoreboardLevelDecorator < ApiDecorator
  def to_hash
    return_hash = {
      id: record.id,
      name: record.name
    }
    return_hash[:points] = record.points if User.current.privilege?(:admin_tasks)
    return_hash
  end
end
