class Solution::FolderVisibilityMapping < ActiveRecord::Base
  self.table_name =  'folder_visibility_mapping'
  self.primary_key = :id

  belongs_to_account
  belongs_to :folder_meta, class_name: 'Solution::FolderMeta', foreign_key: 'folder_meta_id'
  belongs_to :folder, :class_name => 'Solution::Folder'
  belongs_to :mappable, polymorphic: true
  attr_accessible :mappable_id, :mappable_type

  delegate :update_search_index, :to => :folder, :allow_nil => true

  attr_accessible :mappable_id
end
  