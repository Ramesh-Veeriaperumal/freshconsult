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
	include Solution::MarshalDumpMethods

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

    has_one :solution_platform_mapping,
        as: :mappable,
        class_name: 'SolutionPlatformMapping',
        autosave: true,
        dependent: :destroy

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

    has_one :solution_platform_mapping,
      as: :mappable,
      class_name: 'SolutionPlatformMapping',
      autosave: true,
      dependent: :destroy

	COMMON_ATTRIBUTES = ["art_type", "position", "created_at"]

	HITS_CACHE_THRESHOLD = 100

	AGGREGATED_COLUMNS = [:hits, :thumbs_up, :thumbs_down]

	PORTAL_CACHEABLE_ATTRIBUTES = ["id", "account_id", "current_child_id", "title", "solution_folder_meta_id", 
		"status", "modified_at", "created_at", "art_type", "current_child_thumbs_up", "current_child_thumbs_down"]

	before_save :set_default_art_type
	after_commit ->(obj) { obj.safe_send(:clear_cache) }, on: :destroy
	after_commit ->(obj) { obj.safe_send(:clear_cache) }, on: :create
	after_commit ->(obj) { obj.safe_send(:clear_cache_after_update) }, on: :update
	after_commit :update_search_index, on: :update
	after_find :deserialize_attr

	# Need to check this code miss, ember solution test cases get failed if validation is present 
	# validates_inclusion_of :art_type, :in => TYPE_KEYS_BY_TOKEN.values.min..TYPE_KEYS_BY_TOKEN.values.max

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

  scope :for_help_widget, lambda { |help_widget, user|
    {
      conditions: [" solution_folder_meta.solution_category_meta_id in (?) AND #{Solution::FolderMeta.visibility_condition(user)}",
                   help_widget.help_widget_solution_categories.pluck(:solution_category_meta_id)],
      joins: :solution_folder_meta
    }
  }

	delegate :visible_in?, :to => :solution_folder_meta
	delegate :visible?, :to => :solution_folder_meta

	Solution::Article::BODY_ATTRIBUTES.each do |attrib|
		define_method "#{attrib}" do
			self[attrib] || current_article_body.safe_send("#{attrib}")
		end
	end

	AGGREGATED_COLUMNS.each do |col|
		define_method "aggregated_#{col}" do
			return self.safe_send(col) if Account.current.multilingual?
			primary_article.safe_send(col)
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
  		next unless self.safe_send("#{lan}_available?")
      return false unless self.safe_send("#{lan}_outdated?")
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

  def folder_category_info
    [solution_folder_meta, solution_category_meta]
  end

	private

	def clear_cache
		Account.current.clear_solution_categories_from_cache
	end

	def set_default_art_type
		self.art_type ||= Solution::Article::TYPE_KEYS_BY_TOKEN[:permanent]
	end

	def clear_cache_after_update
		clear_cache if previous_changes['solution_folder_meta_id'].present?
	end

	def update_search_index
		solution_articles.map(&:update_es_index) if previous_changes.keys.include?("solution_folder_meta_id")
	end

	def custom_portal_cache_attributes
		{}
	end
end
