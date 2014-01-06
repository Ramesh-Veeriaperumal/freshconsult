# encoding: utf-8
class Solution::Article < ActiveRecord::Base
  include Search::ElasticSearchIndex
  set_table_name "solution_articles"
  serialize :seo_data, Hash

  acts_as_list :scope => :folder

  belongs_to :folder, :class_name => 'Solution::Folder'
  belongs_to :user, :class_name => 'User'
  belongs_to_account
  
  # xss_sanitize :only => [:description],  :html_sanitize => [:description]
  has_many_attachments
  
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
  
  include Mobile::Actions::Article
  include Solution::Constants

  attr_accessor :highlight_title, :highlight_desc_un_html

  attr_protected :account_id ,:attachments
  
  validates_presence_of :title, :description, :user_id , :account_id
  validates_length_of :title, :in => 3..240
  validates_numericality_of :user_id
 
  named_scope :visible, :conditions => ['status = ?',STATUS_KEYS_BY_TOKEN[:published]] 
  named_scope :newest, lambda {|num| {:limit => num, :order => 'updated_at DESC'}}
 
  named_scope :by_user, lambda { |user|
      { :conditions => ["user_id = ?", user.id ] }
  }

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
    id ? "#{id}-#{title.downcase.gsub(/[^a-z0-9]+/i, '-')}" : nil
  end

  def nickname
    title
  end
  
  def to_s
    nickname
  end
  
  def self.suggest_solutions(ticket)
    to_ret = suggest(ticket, ticket.subject)
    to_ret = suggest(ticket, ticket.description) if to_ret.empty?
    
    to_ret

  end
  
  def self.suggest(ticket, search_by)
    return [] if search_by.blank? || (search_by = search_by.gsub(/[\^\$]/, '')).blank?
    begin
      Search::EsIndexDefinition.es_cluster(ticket.account.id)
      options = { :load => true, :page => 1, :size => 10, :preference => :_primary_first }
      item = Tire.search Search::EsIndexDefinition.searchable_aliases([Solution::Article], ticket.account.id), options do |search|
        search.query do |query|
          query.filtered do |f|
            f.query { |q| q.string SearchUtil.es_filter_key(search_by), :fields => ['title', 'desc_un_html'], :analyzer => "include_stop" }
            f.filter :term, { :account_id => ticket.account_id }
          end
        end
        search.from options[:size].to_i * (options[:page].to_i-1)
        search.highlight :desc_un_html, :title, :options => { :tag => '<strong>', :fragment_size => 50, :number_of_fragments => 4, :encoder => 'html' }
      end

      item.results.each_with_hit do |result,hit|
        SearchUtil.highlight_results(result, hit) unless hit['highlight'].blank?
      end
      item.results
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      []
    end
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

  def self.article_type_option
    TYPES.map { |i| [I18n.t(i[1]), i[2]] }
  end

  def self.article_status_option
    STATUSES.map { |i| [I18n.t(i[1]), i[2]] }
  end

end
