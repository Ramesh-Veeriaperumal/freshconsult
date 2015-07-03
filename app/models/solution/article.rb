# encoding: utf-8
class Solution::Article < ActiveRecord::Base
  self.primary_key= :id
  self.table_name =  "solution_articles"

  include Juixe::Acts::Voteable
  include Search::ElasticSearchIndex
  include Mobihelp::AppSolutionsUtils

  include Solution::MetaMethods
  include Solution::LanguageMethods
  include Redis::RedisKeys
  include Redis::OthersRedis	

  concerned_with :associations, :meta_associations
  
  serialize :seo_data, Hash

  concerned_with :body_methods

  acts_as_voteable
  
  spam_watcher_callbacks 

  include Mobile::Actions::Article
  include Solution::Constants
  include Cache::Memcache::Mobihelp::Solution
  include Solution::MetaAssociationSwitcher

  attr_accessor :highlight_title, :highlight_desc_un_html

  attr_accessible :title, :description, :user_id, :folder_id, :status, :art_type, 
    :thumbs_up, :thumbs_down, :delta, :desc_un_html, :import_id, :seo_data, :position
  
  acts_as_list :scope => :folder
  

  before_save     :set_mobihelp_solution_updated_time, :if => :content_changed?
  before_destroy  :set_mobihelp_solution_updated_time

  validates_presence_of :title, :description, :user_id , :account_id
  validates_length_of :title, :in => 3..240
  validates_numericality_of :user_id
 
  scope :visible, :conditions => ['status = ?',STATUS_KEYS_BY_TOKEN[:published]] 
  scope :newest, lambda {|num| {:limit => num, :order => 'modified_at DESC'}}
 
  scope :by_user, lambda { |user|
      { :conditions => ["user_id = ?", user.id ] }
  }

  scope :articles_for_portal, lambda { |portal| articles_for_portal_conditions(portal) }

  VOTE_TYPES = [:thumbs_up, :thumbs_down]

  def self.articles_for_portal_conditions(portal)
    if Account.current.launched?(:meta_read)
      { :conditions => [' solution_folder_meta.solution_category_meta_id in (?) AND solution_folder_meta.visibility = ? ',
          portal.portal_solution_categories.map(&:solution_category_meta_id), Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone] ],
        :joins => :folder_with_meta
      }
    else
      { :conditions => [' solution_folders.category_id in (?) AND solution_folders.visibility = ? ',
          portal.portal_solution_categories.map(&:solution_category_id), Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone] ],
        :joins => :folder }
    end
  end

  def type_name
    TYPE_NAMES_BY_KEY[art_type]
  end
  
  def status_name
    STATUS_NAMES_BY_KEY[status]
  end

  def published?
    status == STATUS_KEYS_BY_TOKEN[:published]
  end
  
  def to_param
    id ? "#{id}-#{title[0..100].downcase.gsub(/[^a-z0-9]+/i, '-')}" : nil
  end

  def nickname
    title
  end
  
  def to_s
    nickname
  end

  def hit!
    new_count = increment_others_redis(hit_key)
    if new_count >= HITS_CACHE_THRESHOLD
      total_hits = read_attribute(:hits) + HITS_CACHE_THRESHOLD
      self.update_column(:hits, total_hits)
      solution_article_meta.update_column(:hits, total_hits) if solution_article_meta
      decrement_others_redis(hit_key, HITS_CACHE_THRESHOLD)
    end
    true
  end

  def hits
    get_others_redis_key(hit_key).to_i + self.read_attribute(:hits)
  end
  
  def related(current_portal, size = 10)
    search_key = "#{tags.map(&:name).join(' ')} #{title}"
    return [] if search_key.blank? || (search_key = search_key.gsub(/[\^\$]/, '')).blank?
    begin
      Search::EsIndexDefinition.es_cluster(account_id)
      options = { :load => true, :page => 1, :size => size, :preference => :_primary_first }
      item = Tire.search Search::EsIndexDefinition.searchable_aliases([Solution::Article], account_id), options do |search|
        search.query do |query|
          query.filtered do |f|
            f.query { |q| q.string SearchUtil.es_filter_key(search_key), :fields => ['title', 'desc_un_html', 'tags.name'], :analyzer => "include_stop" }
            f.filter :term, { :account_id => account_id }
            f.filter :not, { :ids => { :values => [self.id] } }
            f.filter :or, { :not => { :exists => { :field => :status } } },
                          { :not => { :term => { :status => Solution::Constants::STATUS_KEYS_BY_TOKEN[:draft] } } }
            f.filter :or, { :not => { :exists => { :field => 'folder.visibility' } } },
                          { :terms => { 'folder.visibility' => user_visibility } }
            f.filter :or, { :not => { :exists => { :field => 'folder.customer_folders.customer_id' } } },
                          { :term => { 'folder.customer_folders.customer_id' => User.current.customer_id } } if User.current && User.current.has_company?
            f.filter :or, { :not => { :exists => { :field => 'folder.category_id' } } },
                         { :terms => { 'folder.category_id' => current_portal.portal_solution_categories.map(&:solution_category_id) } } unless current_portal.main_portal
          end
        end
        search.from options[:size].to_i * (options[:page].to_i-1)
      end

      item.results.results.compact
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      []
    end
  end

  def user_visibility
    vis_arr = [Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]]
    if User.current
      vis_arr << Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users]
      vis_arr << Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:agents] if User.current.agent?
      vis_arr << Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users] if User.current.has_company?
    end
    vis_arr
  end
  
  def to_xml(options = {})
     options[:root] = 'solution_article'# TODO-RAILS3:: In Rails3 Model.model_name.element returns only 'article' not 'solution_article'
     options[:indent] ||= 2
     options.merge!(Solution::Constants::API_OPTIONS.merge(:include => {}))
      xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => options[:except], :root => options[:root]) 
  end

  def to_indexed_json
    as_json(
            :root => "solution/article",
            :tailored_json => true,
            :only => [ :title, :desc_un_html, :user_id, :folder_id, :status, :account_id, :created_at, :updated_at ],
            :include => { :tags => { :only => [:name] },
                          :folder => { :only => [:category_id, :visibility], 
                                       :include => { :customer_folders => { :only => [:customer_id] } }
                                     },
                          :attachments => { :only => [:content_file_name] }
                        }
           ).to_json
  end
 
  def as_json(options={})
    return super(options) unless options[:tailored_json].blank?
    options.merge!(Solution::Constants::API_OPTIONS)
    super options
  end

  # Added for portal customisation drop
  def self.filter(_per_page = self.per_page, _page = 1)
    paginate :per_page => _per_page, :page => _page
  end
  
  def to_liquid
    @solution_article_drop ||= Solution::ArticleDrop.new self
  end
  
  def article_title
    (seo_data[:meta_title].blank?) ? title : seo_data[:meta_title]
  end

  def article_description
    seo_data[:meta_description]
  end

  def article_keywords
    (seo_data[:meta_keywords].blank?) ? tags.join(", ") : seo_data[:meta_keywords]
  end

  def article_changes
    @article_changes ||= self.changes.clone
  end

  VOTE_TYPES.each do |method|
    define_method "toggle_#{method}!" do
      increment(method)
      decrement((VOTE_TYPES - [method]).first)
      save!
    end
  end

  def self.article_type_option
    TYPES.map { |i| [I18n.t(i[1]), i[2]] }
  end

  def self.article_status_option
    STATUSES.map { |i| [I18n.t(i[1]), i[2]] }
  end

  private

    def set_mobihelp_solution_updated_time
      update_mh_solutions_category_time(self.solution_folder.category_id)
    end

    def content_changed?
      all_fields = [:title, :description, :status, :position]
      changed_fields = self.changes.symbolize_keys.keys
      (changed_fields & all_fields).any?
    end
    
    def hit_key
      SOLUTION_HIT_TRACKER % {:account_id => account_id, :article_id => id }
    end
    
end
