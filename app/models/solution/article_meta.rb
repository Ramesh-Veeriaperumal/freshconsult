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
	delegate :description, :desc_un_html, :to => :current_article_body
	
	after_find :deserialize_attr

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
	
	def current_article_body
		Account.current.solution_article_bodies.find_by_article_id(current_child_id)
	end
	
	def to_param
		title_param = sterilize(title[0..100])
		id ? "#{id}-#{title_param.downcase.gsub(/[<>#%{}|()*+_\\^~\[\]`\s,=&:?;'@$"!.\/(\-\-)]+/, '-')}" : nil
	end
	
	def self.filter(_per_page = self.per_page, _page = 1)
		paginate :per_page => _per_page, :page => _page
	end
end
