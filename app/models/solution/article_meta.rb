class Solution::ArticleMeta < ActiveRecord::Base

	self.primary_key = :id
	belongs_to_account
	self.table_name = "solution_article_meta"

	include Redis::RedisKeys
	include Redis::OthersRedis
	include Community::HitMethods
	include Solution::LanguageAssociations
	include Solution::Constants
	include Solution::ApiDelegator
	include Solution::UrlSterilize

	has_many :solution_articles, :class_name => "Solution::Article", :foreign_key => :parent_id, :autosave => true

	belongs_to :solution_folder_meta,
		:class_name => "Solution::FolderMeta",
		:foreign_key => :solution_folder_meta_id

	has_one :solution_folder, :class_name => "Solution::Folder", :through => :solution_folder_meta

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
	
	after_find :deserialize_attr
	
	Solution::Article::BODY_ATTRIBUTES.each do |attrib|
		define_method "#{attrib}" do
			self[attrib] || current_article_body.send("#{attrib}")
		end
	end

	def hit_key
		SOLUTION_META_HIT_TRACKER % {:account_id => account_id, :article_meta_id => id }
	end
	
	def deserialize_attr
		self.attributes.slice(*Solution::Article.serialized_attributes.keys).each do |k, v|
			self[k] = YAML.load(v)
		end
	end
	
	def to_liquid
		@solution_article_meta_drop ||= (Solution::ArticleMetaDrop.new self)
	end
	
	def to_param
		title_param = sterilize(title[0..100])
		id ? "#{id}-#{title_param.downcase.gsub(/[<>#%{}|()*+_\\^~\[\]`\s,=&:?;'@$"!.\/(\-\-)]+/, '-')}" : nil
	end
	
	def self.filter(_per_page = self.per_page, _page = 1)
		paginate :per_page => _per_page, :page => _page
	end
end
