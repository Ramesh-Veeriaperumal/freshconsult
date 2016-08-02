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
	include Solution::ApiDelegator
	include Solution::UrlSterilize

	attr_accessible :position, :art_type, :solution_folder_meta_id

	has_many :solution_articles,
		:inverse_of => :solution_article_meta,
		:class_name => "Solution::Article",
		:foreign_key => :parent_id,
		:autosave => true,
		:dependent => :destroy

	belongs_to :solution_folder_meta, 
		:class_name => "Solution::FolderMeta", 
		:foreign_key => :solution_folder_meta_id, 
		:autosave => true

	has_one :solution_category_meta,
		:through => :solution_folder_meta,
		:class_name => "Solution::CategoryMeta"
			
	has_one :solution_folder, 
		:through => :solution_folder_meta,
		:class_name => "Solution::Folder"

	acts_as_list :scope => :solution_folder_meta

	has_one :current_article_body, :class_name => "Solution::ArticleBody", :foreign_key => :article_id, :primary_key => :current_child_id

	has_many :tag_uses,
		:class_name => 'Helpdesk::TagUse',
		:foreign_key => :taggable_id, 
		:primary_key => :current_child_id,
		:conditions => { :taggable_type => "Solution::Article" }

	has_many :tags, 
		:class_name => 'Helpdesk::Tag',
		:through => :tag_uses

	COMMON_ATTRIBUTES = ["art_type", "position", "created_at"]

	HITS_CACHE_THRESHOLD = 100

	AGGREGATED_COLUMNS = [:hits, :thumbs_up, :thumbs_down]
	
	before_save :set_default_art_type
	after_commit ->(obj) { obj.send(:clear_cache) }, on: :destroy
	after_commit ->(obj) { obj.send(:clear_cache) }, on: :create
	after_commit ->(obj) { obj.send(:clear_cache_after_update) }, on: :update
	after_commit :update_search_index, on: :update
	after_find :deserialize_attr

	after_save :set_mobihelp_solution_updated_time, :if => :valid_change?
	before_destroy :set_mobihelp_solution_updated_time

	validates_inclusion_of :art_type, :in => TYPE_KEYS_BY_TOKEN.values.min..TYPE_KEYS_BY_TOKEN.values.max

	alias_method :children, :solution_articles

	scope :published, lambda {
		{
			:joins => :current_article,
			:conditions => ["`solution_articles`.status = ?", STATUS_KEYS_BY_TOKEN[:published]]
		}
	}

	scope :visible_to_all, lambda { joins(:solution_folder_meta).where(
		"`solution_folder_meta`.visibility = ? ", Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:anyone]).published }

	scope :newest, lambda { |num|
		{
			:joins => :current_article,
			:conditions => ["`solution_articles`.language_id = ?", Language.for_current_account.id],
			:order => ["`solution_articles`.modified_at DESC"],
			:limit => num
		}
	}

	scope :for_portal, lambda { |portal|
		{
			:conditions => [' solution_folder_meta.solution_category_meta_id in (?) AND solution_folder_meta.visibility = ? ',
	          portal.portal_solution_categories.pluck(:solution_category_meta_id), Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:anyone] ],
	        :joins => :solution_folder_meta
      	}
	}

	delegate :visible_in?, :to => :solution_folder_meta
	delegate :visible?, :to => :solution_folder_meta

	Solution::Article::BODY_ATTRIBUTES.each do |attrib|
		define_method "#{attrib}" do
			self[attrib] || current_article_body.send("#{attrib}")
		end
	end

	AGGREGATED_COLUMNS.each do |col|
		define_method "aggregated_#{col}" do
			return self.send(col) if Account.current.multilingual?
			primary_article.send(col)
		end
	end	

	def hit_key
		SOLUTION_META_HIT_TRACKER % {:account_id => account_id, :article_meta_id => id }
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
	
	def deserialize_attr
		# In the customer portal, we select attributes of the current language article from solution_articles table
		# along with each article_meta object. So if we try to fetch a serialized attribute of the current child article 
		# through the parent object, it had the raw content(serialized string) from the table. Hence, we had
		# to deserialize any such attributes.
		self.attributes.slice(*Solution::Article.serialized_attributes.keys).each do |k, v|
			self[k] = YAML.load(v)
		end
	end
	
	def to_liquid
		@solution_article_drop ||= (Solution::ArticleDrop.new self)
	end
	
	def to_param
		title_param = sterilize(self.title[0..100])
		id ? "#{id}-#{title_param.downcase.gsub(/[<>#%{}|()*+_\\^~\[\]`\s,=&:?;'@$"!.\/(\-\-)]+/, '-')}" : nil
	end
	
	def self.filter(_per_page = self.per_page, _page = 1)
		paginate :per_page => _per_page, :page => _page
	end

	def set_mobihelp_solution_updated_time
		self.reload
		solution_folder_meta.solution_category_meta.update_mh_solutions_category_time
	end

	private

	def clear_cache
		Account.current.clear_solution_categories_from_cache
	end

	def set_default_art_type
		self.art_type ||= Solution::Article::TYPE_KEYS_BY_TOKEN[:permanent]
	end
	
	def valid_change?
		self.changes.slice(:position).present? || 
			(primary_article && (primary_article.previous_changes.slice(*[:modified_at, :status]).present? || 
			primary_article.tags_changed))
	end

	def clear_cache_after_update
		clear_cache if previous_changes['solution_folder_meta_id'].present?
	end

	def update_search_index
		solution_articles.map(&:update_es_index) if previous_changes.keys.include?("solution_folder_meta_id")
	end
end
