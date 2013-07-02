# encoding: utf-8
class Solution::Article < ActiveRecord::Base
  include Search::ElasticSearchIndex
  set_table_name "solution_articles"
  serialize :seo_data, Hash

  acts_as_list :scope => :folder

  belongs_to :folder, :class_name => 'Solution::Folder'
  belongs_to :user, :class_name => 'User'
  belongs_to :account
  
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

  define_index do
    indexes :title, :sortable => true
    indexes :desc_un_html, :as => :description
    indexes tags.name , :as => :tags

    has account_id, user_id, status
    has folder.category_id, :as => :category_id 
    has '0', :as => :deleted, :type => :boolean    
    has folder.visibility , :as => :visibility, :type => :integer
    has SearchUtil::DEFAULT_SEARCH_VALUE, :as => :responder_id, :type => :integer
    has SearchUtil::DEFAULT_SEARCH_VALUE, :as => :group_id, :type => :integer
    has folder.customer_folders(:customer_id), :as => :customer_ids,:type => :multi

    has SearchUtil::DEFAULT_SEARCH_VALUE, :as => :requester_id, :type => :integer
    has SearchUtil::DEFAULT_SEARCH_VALUE, :as => :customer_id, :type => :integer

    #set_property :delta => :delayed
    set_property :field_weights => {
      :title        => 10,
      :description  => 6
    }
  end

  attr_protected :account_id ,:attachments
  
  validates_presence_of :title, :description, :user_id , :account_id
  validates_length_of :title, :in => 3..240
  validates_numericality_of :user_id
 
  named_scope :visible, :conditions => ['status = ?',STATUS_KEYS_BY_TOKEN[:published]] 
 
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
      if ticket.account.es_enabled?
        begin
          options = { :load => true, :page => 1, :size => 10, :preference => :_primary_first }
          item = Tire.search [ticket.account.search_index_name], options do |search|
            search.query do |query|
              query.filtered do |f|
                f.query { |q| q.string SearchUtil.es_filter_key(search_by), :fields => ['title', 'desc_un_html'], :analyzer => "include_stop" }
                f.filter :terms, :_type => ['solution/article']
                f.filter :term, { :account_id => ticket.account_id }
              end
            end
            search.from options[:size].to_i * (options[:page].to_i-1)
            search.highlight :desc_un_html, :title, :options => { :tag => '<strong>', :fragment_size => 50, :number_of_fragments => 4 }
          end

          item.results.each_with_hit do |result,hit|
            unless result.blank?
              hit['highlight'].keys.each do |i|
                result[i] = hit['highlight'][i].to_s
              end
            end
          end
          item.results
        rescue Exception => e
          NewRelic::Agent.notice_error(e)
          []
        end
    else
      ThinkingSphinx.search(search_by, :with => { :account_id => ticket.account.id },
       :classes => [ Solution::Article ], :match_mode => :any, :per_page => 10 )
    end
  end
  
  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:except => [:account_id,:import_id]) 
  end

  def to_indexed_json
    to_json(
            :root => "solution/article",
            :only => [ :title, :desc_un_html, :user_id, :status, :account_id ],
            :include => { :tags => { :only => [:name] },
                          :folder => { :only => [:category_id, :visibility], 
                                       :include => { :customer_folders => { :only => [:customer_id] } }
                                     },
                          :attachments => { :only => [:content_file_name] }
                        }
           )
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

end
