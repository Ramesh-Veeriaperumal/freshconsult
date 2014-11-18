# encoding: utf-8
class Solution::Article < ActiveRecord::Base
  include Juixe::Acts::Voteable
  include Search::ElasticSearchIndex
  set_table_name "solution_articles"
  serialize :seo_data, Hash

  acts_as_voteable
  acts_as_list :scope => :folder

  belongs_to :folder, :class_name => 'Solution::Folder'
  belongs_to :user, :class_name => 'User'
  belongs_to_account
  
  # xss_sanitize :only => [:description],  :html_sanitize => [:description]
  has_many :voters, :through => :votes, :source => :user, :uniq => true, :order => "#{Vote.table_name}.id DESC"
  
  has_many_attachments
  has_many_cloud_files
  spam_watcher_callbacks 
  
  has_many :activities,
    :class_name => 'Helpdesk::Activity',
    :as => 'notable',
    :dependent => :destroy
  has_many :tag_uses,
    :as => :taggable,
    :class_name => 'Helpdesk::TagUse',
    :dependent => :destroy
  has_many :tags, 
    :class_name => 'Helpdesk::Tag',
    :through => :tag_uses

  has_many :support_scores, :as => :scorable, :dependent => :destroy

  has_many :article_ticket, :dependent => :destroy
  has_many :tickets, :through => :article_ticket
  
  include Mobile::Actions::Article
  include Solution::Constants
  include Cache::Memcache::Mobihelp::Solution

  attr_accessor :highlight_title, :highlight_desc_un_html

  attr_protected :account_id ,:attachments
  
  after_commit_on_create  :clear_mobihelp_solutions_cache
  after_commit_on_update  :clear_mobihelp_solutions_cache
  before_destroy          :clear_mobihelp_solutions_cache

  validates_presence_of :title, :description, :user_id , :account_id
  validates_length_of :title, :in => 3..240
  validates_numericality_of :user_id
 
  named_scope :visible, :conditions => ['status = ?',STATUS_KEYS_BY_TOKEN[:published]] 
  named_scope :newest, lambda {|num| {:limit => num, :order => 'modified_at DESC'}}
 
  named_scope :by_user, lambda { |user|
      { :conditions => ["user_id = ?", user.id ] }
  }

  named_scope :articles_for_portal, lambda { |portal|
    {
      :conditions => [' solution_folders.category_id in (?) AND solution_folders.visibility = ? ',
          portal.portal_solution_categories.map(&:solution_category_id), Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone] ],
      :joins => :folder
    }
  }

  VOTE_TYPES = [:thumbs_up, :thumbs_down]

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
    self.class.increment_counter :hits, id
  end

  
  def related(current_portal, size = 10)
    return [] if title.blank? || (title = self.title.gsub(/[\^\$]/, '')).blank?
    begin
      Search::EsIndexDefinition.es_cluster(account_id)
      options = { :load => true, :page => 1, :size => size, :preference => :_primary_first }
      item = Tire.search Search::EsIndexDefinition.searchable_aliases([Solution::Article], account_id), options do |search|
        search.query do |query|
          query.filtered do |f|
            f.query { |q| q.string SearchUtil.es_filter_key(title), :fields => ['title', 'desc_un_html'], :analyzer => "include_stop" }
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

      item.results.results
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
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id]) 
  end

  def to_indexed_json
    to_json(
            :root => "solution/article",
            :tailored_json => true,
            :only => [ :title, :desc_un_html, :user_id, :folder_id, :status, :account_id, :created_at, :updated_at ],
            :include => { :tags => { :only => [:name] },
                          :folder => { :only => [:category_id, :visibility], 
                                       :include => { :customer_folders => { :only => [:customer_id] } }
                                     },
                          :attachments => { :only => [:content_file_name] }
                        }
           )
  end
 
  def as_json(options={})
    return super(options) unless options[:tailored_json].blank?
    options[:except]=[:account_id,:import_id]
    options[:include]={ :tags => { :only => [:name] },
                        :folder => { :except => [:account_id,:import_id],
                                     :include => { :customer_folders => { :only => [:customer_id] } }
                                   }
                        }
    json_str=super options
    return json_str
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
  
    def clear_mobihelp_solutions_cache
      clear_solutions_cache(self.folder.category_id)
    end
end
