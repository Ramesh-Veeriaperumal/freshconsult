class Solution::FolderMeta < ActiveRecord::Base

	self.primary_key = :id
  
	self.table_name = "solution_folder_meta"
  include Solution::Constants
	include Solution::LanguageAssociations
	belongs_to_account
	
  validates_inclusion_of :visibility, 
      :in => VISIBILITY_KEYS_BY_TOKEN.values.min..VISIBILITY_KEYS_BY_TOKEN.values.max

	belongs_to :solution_category_meta, :class_name => 'Solution::CategoryMeta'

	has_many :solution_folders, :class_name => "Solution::Folder", :foreign_key => "parent_id", :autosave => true, :dependent => :destroy

	has_many :customer_folders , :class_name => 'Solution::CustomerFolder' , :dependent => :destroy

	has_many :customers, :through => :customer_folders

	has_many :solution_article_meta, :class_name => "Solution::ArticleMeta", :foreign_key => :solution_folder_meta_id, :order => :position, :dependent => :destroy

	has_many :solution_articles, 
		:class_name => "Solution::Article", 
		:through => :solution_article_meta,
		:order => :"solution_article_meta.position"

	COMMON_ATTRIBUTES = ["visibility", "position", "is_default", "created_at"]
	CACHEABLE_ATTRIBUTES  = ["is_default","name","id","article_count"]

	after_create :clear_cache
	after_destroy :clear_cache
	after_update :clear_cache_with_condition

	def article_count
	  solution_article_meta.size
	end

	def as_cache
	  (CACHEABLE_ATTRIBUTES.inject({}) do |res, attribute|
	    res.merge({ attribute => self.send(attribute) })
	  end).with_indifferent_access
	end

	private

	def clear_cache
		account.clear_solution_categories_from_cache
	end

	def clear_cache_with_condition
		account.clear_solution_categories_from_cache unless (self.changes.keys & ['solution_category_meta_id', 'position']).empty?
	end

end
