class Solution::ArticleMeta < ActiveRecord::Base

	self.primary_key = :id
	belongs_to_account
	self.table_name = "solution_article_meta"
	
	BINARIZE_COLUMNS = [:available, :outdated, :draft_present, :published]
	
	include Redis::RedisKeys
	include Redis::OthersRedis
	include Community::HitMethods
	include Solution::Constants
	include Solution::LanguageAssociations

	delegate :draft, :status, :user, :to => :primary_article

	has_many :solution_articles, :class_name => "Solution::Article", :foreign_key => :parent_id, :autosave => true, :inverse_of => :solution_article_meta, :dependent => :destroy

	belongs_to :solution_folder_meta, 
		:class_name => "Solution::FolderMeta", 
		:foreign_key => :solution_folder_meta_id, :autosave => true

	has_one :solution_category_meta,
		:class_name => "Solution::CategoryMeta",
		:through => :solution_folder_meta
			
	has_one :solution_folder, :class_name => "Solution::Folder", :through => :solution_folder_meta

	acts_as_list :scope => :solution_folder_meta

	COMMON_ATTRIBUTES = ["art_type", "position", "created_at"]
	
	HITS_CACHE_THRESHOLD = 100

	before_save :set_default_art_type
	after_create :clear_cache
	after_destroy :clear_cache
	after_update :clear_cache, :if => :solution_folder_meta_id_changed?

	alias_method :children, :solution_articles

	def hit_key
		SOLUTION_META_HIT_TRACKER % {:account_id => account_id, :article_meta_id => id }
	end

	def self.translations_with_draft
    base_name = self.name.chomp('Meta').gsub("Solution::", '').downcase
    (['primary'] | Account.current.applicable_languages).collect(&:to_sym).collect {|s| {:"#{s}_#{base_name}" => :draft}}
  end

  def type_name
  	TYPE_NAMES_BY_KEY[art_type]
  end

  def all_versions_outdated?
  	Account.current.applicable_languages.each do |lan|
  		next unless self.send("#{lan}_available?")
      return false unless self.send("#{lan}_outdated?")
    end
    true
  end

	private

	def clear_cache
		account.clear_solution_categories_from_cache
	end

	def set_default_art_type
		self.art_type ||= Solution::Article::TYPE_KEYS_BY_TOKEN[:permanent]
	end

end