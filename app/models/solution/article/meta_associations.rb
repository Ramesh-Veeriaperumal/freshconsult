class Solution::Article < ActiveRecord::Base

  belongs_to :solution_article_meta, :class_name => "Solution::ArticleMeta", :foreign_key => "parent_id"

  has_one :solution_folder_meta, :class_name => "Solution::FolderMeta", :through => :solution_article_meta

  has_one :folder_with_meta,
    :source => :solution_folders,
    :class_name => 'Solution::Folder',
    :through => :solution_folder_meta,
    :conditions => proc { "solution_folders.language_id = '#{Solution::LanguageMethods.current_language_id}'" }

  FEATURE_BASED_METHODS.each do |method|
    alias_method_chain method, :meta
  end

end