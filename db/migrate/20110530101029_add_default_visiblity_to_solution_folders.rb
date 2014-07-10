class AddDefaultVisiblityToSolutionFolders < ActiveRecord::Migration
 def self.up
    Solution::Folder.all.each do |folder|
      folder.visibility = Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]
      folder.save!
    end    
  end

  def self.down
    Solution::Folder.all.each do |folder|
      folder.visibility = null
      folder.save!
    end
  end
end
