class AddDefaultForumVisibilityToForums < ActiveRecord::Migration
  def self.up
    Forum.all.each do |forum|
      forum.forum_visibility = Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone]
      forum.save!
    end    
  end

  def self.down
    Forum.all.each do |forum|
      forum.forum_visibility = null
      forum.save!
    end
  end
end
