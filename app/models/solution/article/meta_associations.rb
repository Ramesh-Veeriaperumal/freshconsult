class Solution::Article < ActiveRecord::Base

  belongs_to :solution_article_meta, :class_name => "Solution::ArticleMeta", :foreign_key => "parent_id", :readonly => false

  has_one :solution_folder_meta, :class_name => "Solution::FolderMeta", :through => :solution_article_meta, :readonly => false

  has_one :folder_with_meta,
    :source => :solution_folders,
    :class_name => 'Solution::Folder',
    :through => :solution_folder_meta,
	:readonly => false,
    :conditions => proc { "solution_folders.language_id = '#{Solution::Folder.current_language_id}'" }
end