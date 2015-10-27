# encoding: utf-8
class Solution::Article < ActiveRecord::Base
  self.primary_key= :id
  self.table_name =  "solution_articles"
  belongs_to_account
  concerned_with :associations, :meta_associations, :body_methods
  
  include Juixe::Acts::Voteable
  include Search::ElasticSearchIndex

  include Solution::MetaMethods

  belongs_to :recent_author, :class_name => 'User', :foreign_key => "modified_by"
  has_one :draft, :dependent => :destroy

  include Solution::LanguageMethods
  # include Solution::MetaAssociationSwitcher### MULTILINGUAL SOLUTIONS - META READ HACK!!
  
  include Mobile::Actions::Article
  include Solution::Constants
  include Cache::Memcache::Mobihelp::Solution
  
  include Community::HitMethods
  include Redis::RedisKeys
  include Redis::OthersRedis

  spam_watcher_callbacks
  rate_limit :rules => lambda{ |obj| Account.current.account_additional_settings_from_cache.resource_rlimit_conf['solution_articles'] }, :if => lambda{|obj| obj.rl_enabled? }
  
  acts_as_voteable
  
  
  serialize :seo_data, Hash
  
  attr_accessor :highlight_title, :highlight_desc_un_html, :tags_changed

  attr_accessible :title, :description, :user_id, :folder_id, :status, :art_type, 
    :thumbs_up, :thumbs_down, :delta, :desc_un_html, :import_id, :seo_data, :position
  
  acts_as_list :scope => :folder
  

  after_save      :set_mobihelp_solution_updated_time, :if => :content_changed?
  before_destroy  :set_mobihelp_solution_updated_time

  validates_presence_of :title, :description, :user_id , :account_id
  validates_length_of :title, :in => 3..240
  validates_numericality_of :user_id
  validates_uniqueness_of :language_id, :scope => [:account_id , :parent_id]
  validate :status_in_default_folder

  ### MULTILINGUAL SOLUTIONS - META READ HACK!!
  default_scope proc {
    Account.current.launched?(:meta_read) ? joins(:solution_article_meta).preload(:solution_article_meta) : unscoped
  }
 
  scope :visible, :conditions => ['status = ?',STATUS_KEYS_BY_TOKEN[:published]] 
  scope :newest, lambda {|num| {:limit => num, :order => 'modified_at DESC'}}
 
  scope :by_user, lambda { |user|
      { :conditions => ["user_id = ?", user.id ] }
  }

  scope :articles_for_portal, lambda { |portal| articles_for_portal_conditions(portal) }

  delegate :visible_in?, :to => :solution_folder_meta
  delegate :visible?, :to => :solution_folder_meta

  VOTE_TYPES = [:thumbs_up, :thumbs_down]


  ### MULTILINGUAL SOLUTIONS - META READ HACK!!
  def self.articles_for_portal_conditions(portal)
    { :conditions => [' solution_folders.category_id in (?) AND solution_folders.visibility = ? ',
        portal.portal_solution_categories.map(&:solution_category_id), Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone] ],
      :joins => :folder,
      :order => ['solution_articles.folder_id', "solution_articles.position"] }
  end

  ### MULTILINGUAL SOLUTIONS - META READ HACK!!
  def self.articles_for_portal_conditions_through_meta(portal)
    { :conditions => [' solution_folder_meta.solution_category_meta_id in (?) AND solution_folder_meta.visibility = ? ',
          portal.portal_solution_categories.map(&:solution_category_meta_id), Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone] ],
        :joins => :folder_through_meta,
        :order => ["solution_article_meta.solution_folder_meta_id", "solution_article_meta.position"]
      }
  end

  ### MULTILINGUAL SOLUTIONS - META READ HACK!!
  def self.articles_for_portal_conditions_with_association(portal)
    if Account.current.launched?(:meta_read)
      self.articles_for_portal_conditions_through_meta(portal)
    else
      self.articles_for_portal_conditions_without_association(portal)
    end
  end

  ### MULTILINGUAL SOLUTIONS - META READ HACK!!
  class << self
    alias_method_chain :articles_for_portal_conditions, :association
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
    parent_id ? "#{parent_id}-#{title[0..100].downcase.gsub(/[^a-z0-9]+/i, '-')}" : nil
  end

  def nickname
    title
  end
  
  def to_s
    nickname
  end
  
  def related(current_portal, size = 10)
    search_key = "#{tags.map(&:name).join(' ')} #{title}"
    return [] if search_key.blank? || (search_key = search_key.gsub(/[\^\$]/, '')).blank?
    begin
      @search_lang = ({ :language => current_portal.language }) if current_portal and Account.current.features_included?(:es_multilang_solutions)
      Search::EsIndexDefinition.es_cluster(account_id)
      options = { :load => true, :page => 1, :size => size, :preference => :_primary_first }
      item = Tire.search Search::EsIndexDefinition.searchable_aliases([Solution::Article], account_id, @search_lang), options do |search|
        search.query do |query|
          query.filtered do |f|
            f.query { |q| q.string SearchUtil.es_filter_key(search_key), :fields => ['title', 'desc_un_html', 'tags.name'], :analyzer => SearchUtil.analyzer(@search_lang) }
            f.filter :term, { :account_id => account_id }
            f.filter :term, { :language_id => Language.for_current_account.id }
            f.filter :not, { :ids => { :values => [self.id] } }
            f.filter :or, { :not => { :exists => { :field => :status } } },
                          { :not => { :term => { :status => Solution::Constants::STATUS_KEYS_BY_TOKEN[:draft] } } }
            f.filter :or, { :not => { :exists => { :field => 'folder.visibility' } } },
                          { :terms => { 'folder.visibility' => user_visibility } }
            f.filter :or, { :not => { :exists => { :field => 'folder.customer_folders.customer_id' } } },
                          { :term => { 'folder.customer_folders.customer_id' => User.current.customer_id } } if User.current && User.current.has_company?
            f.filter :or, { :not => { :exists => { :field => 'folder.category_id' } } },
                         { :terms => { 'folder.category_id' => current_portal.portal_solution_categories.map(&:solution_category_id) } }
            f.filter :or, { :not => { :exists => { :field => 'language_id' } } },
                         { :term => { 'language_id' => Language.current.id } }
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
    article_json = as_json(
            :root => "solution/article",
            :tailored_json => true,
            :only => [ :title, :desc_un_html, :user_id, :status, 
                  :language_id, :account_id, :created_at, :updated_at ],
            :include => { :tags => { :only => [:name] },
                          :attachments => { :only => [:content_file_name] }
                        }
          )
    article_json["solution/article"].merge!(meta_attributes)
    article_json.to_json
  end

  def meta_attributes
    { 
      :folder_id => solution_folder_meta.id,
      :folder => { 
        "category_id" => solution_folder_meta.solution_category_meta_id,
        "visibility" => solution_folder_meta.visibility,
        :customer_folders => solution_folder_meta.customer_folders.map {|cf| {"customer_id" => cf.customer_id} }
      }
    }
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
      self.class.update_counters(self.id, method => 1, (VOTE_TYPES - [method]).first => -1 )
      meta_class.update_counters(self.parent_id, method => 1, (VOTE_TYPES - [method]).first => -1 )
      queue_quest_job if self.published?
      return true
    end

    define_method "#{method}!" do
      self.class.increment_counter(method, self.id)
      meta_class.increment_counter(method, self.parent_id)
      queue_quest_job if (method == :thumbs_up && self.published?)
      return true
    end
  end

  def reset_ratings
    self.class.update_all({:thumbs_up => 0, :thumbs_down => 0} ,{ :id => self.id})
    meta_class.update_counters(self.parent_id, :thumbs_up => -self.thumbs_up, :thumbs_down => -self.thumbs_down)
    self.votes.destroy_all
  end

  def self.article_type_option
    TYPES.map { |i| [I18n.t(i[1]), i[2]] }
  end

  def self.article_status_option
    STATUSES.map { |i| [I18n.t(i[1]), i[2]] }
  end
  
  # Instance level spam watcher condition
  def rl_enabled?
    self.account.features?(:resource_rate_limit)
  end

  def create_draft_from_article(opts = {})
    draft = build_draft_from_article(opts)
    draft.save
    draft
  end

  def build_draft_from_article(opts = {})
    draft = self.account.solution_drafts.build(draft_attributes(opts))
    draft
  end

  def draft_attributes(opts = {})
    draft_attrs = opts.merge(:article => self, :category_meta => solution_folder_meta.solution_category_meta)
    Solution::Draft::COMMON_ATTRIBUTES.each do |attribute|
      draft_attrs[attribute] = self.send(attribute)
    end
    draft_attrs
  end

  def set_status(publish)
    self.status = publish ? STATUS_KEYS_BY_TOKEN[:published] : STATUS_KEYS_BY_TOKEN[:draft]
  end

  def publish!
    set_status(true)
    save
  end

  def is_primary?
    self.id == self.solution_article_meta.primary_article.id
  end

  private

    def queue_quest_job
      Resque.enqueue(Gamification::Quests::ProcessSolutionQuests, { :id => self.id, 
        :account_id => self.account_id })
    end

    def set_mobihelp_solution_updated_time
      category_obj.update_mh_solutions_category_time
    end

    def category_obj
      self.reload
      solution_folder_meta.solution_category_meta
    end

    def content_changed?
      all_fields = [:modified_at, :status, :position]
      changed_fields = self.changes.symbolize_keys.keys
      (changed_fields & all_fields).any? or tags_changed
    end

    def status_in_default_folder
      if status == STATUS_KEYS_BY_TOKEN[:published] and self.solution_folder_meta.is_default
        errors.add(:status, I18n.t('solution.articles.cant_publish'))
      end
    end
    
    def hit_key
      SOLUTION_HIT_TRACKER % {:account_id => account_id, :article_id => id }
    end

    def rl_exceeded_operation
      key = "RL_%{table_name}:%{account_id}:%{user_id}" % {:table_name => self.class.table_name, :account_id => self.account_id,
            :user_id => self.user_id }
      $spam_watcher.rpush(ResourceRateLimit::NOTIFY_KEYS, key)
    end
    
end
