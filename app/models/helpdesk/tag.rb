# encoding: utf-8
class Helpdesk::Tag < ActiveRecord::Base
  
  self.primary_key = :id
  include Cache::Memcache::Helpdesk::Tag
  include Search::ElasticSearchIndex

  concerned_with :presenter
  attr_accessor :model_changes
  before_save :save_model_changes

  after_commit  :clear_cache
  after_commit  :update_taggables, on: :update
  after_commit  :remove_taguses, on: :destroy
  before_destroy :save_deleted_tag_info

  publishable on: [:create, :update, :destroy]
  
  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher

  self.table_name =  "helpdesk_tags"
  
  xss_sanitize  :only => [:name], :plain_sanitizer => [:name]

  belongs_to_account

  has_many :tag_uses,
    :class_name => 'Helpdesk::TagUse'

  has_many :tickets,
    :class_name => 'Helpdesk::Ticket',
    :source => :taggable,
    :source_type => "Helpdesk::Ticket",
    :through => :tag_uses

  has_many :archive_tickets,
    :class_name => 'Helpdesk::ArchiveTicket',
    :source => :taggable,
    :source_type => "Helpdesk::ArchiveTicket",
    :through => :tag_uses

  has_many :users,
    :class_name => 'User',
    :source => :taggable,
    :source_type => "User",
    :through => :tag_uses

  has_many :contacts,
    :class_name => 'User',
    :source => :taggable,
    :source_type => "User",
    :through => :tag_uses,
    :conditions => { :helpdesk_agent => false, :deleted => false }

  has_many :solution_articles,
           :class_name => 'Solution::Article',
           :source => :taggable,
           :source_type => "Solution::Article",
           :through => :tag_uses

  scope :with_taggable_type, -> (taggable_type) {
            includes(tag_uses).
            where(["helpdesk_tag_uses.taggable_type = ?", taggable_type])

  has_many :folder_meta,
           class_name: 'Solution::FolderMeta',
           source: :taggable,
           source_type: 'Solution::FolderMeta',
           through: :tag_uses
        }

  scope :most_used, -> (num) { limit(num).order('tag_uses_count DESC') }

  scope :sort_tags, -> (sort_type) { order(SORT_SQL_BY_KEY[(sort_type).to_sym] || SORT_SQL_BY_KEY[:activity_desc]) }

  scope :tag_search, -> (keyword) { where(["name like ?","#{keyword}%"]) if keyword.present? }

  swindle :basic_info,
        attrs: %i[name]

  SORT_FIELDS = [
    [ :activity_desc, 'Most Used',    "tag_uses_count DESC"  ],
    [ :activity_asc,  'Least Used',   "tag_uses_count ASC"  ],
    [ :name_asc,      'Name (a..z)',  "name ASC"  ],
    [ :name_desc,     'Name (z..a)',  "name DESC"  ]
  ]

  SORT_FIELD_OPTIONS = SORT_FIELDS.map { |i| [i[1], i[0]] }
  SORT_SQL_BY_KEY = Hash[*SORT_FIELDS.map { |i| [i[0], i[2]] }.flatten]

  validates_presence_of :name
  validates_length_of :name, :in => (1..32)
  
  def nickname
    name
  end

  def uses_count
    self.tag_uses_count.blank? ? 0: self.tag_uses_count
  end

  def tag_size(biggest = 1)
    min = -20
    max = 50

    font_size = 100
    font_size += (self.uses_count / biggest * (max-min) ) + min if biggest > 1 and self.uses_count > 0
    
    font_size
  end

  def to_param
    id ? "#{id}-#{name.downcase.gsub(/[^a-z0-9]+/i, '-')}" : nil
  end

  def to_s
    return name
  end
  
  def to_liquid
    @helpdesk_tag_drop ||= (Helpdesk::TagDrop.new self)
  end

  def ticket_count
    tickets.visible.size
  end

  # Common handler for creating/removing tags
  def self.assign_tags(tags_to_be_added=[])
    return [] if tags_to_be_added.blank?

    missing_tags = []
    tag_list     = []

    existing_tags = self.where(name: tags_to_be_added).all
    tag_list.push(*existing_tags) # Pushing to the array so that when .any? called is made, it wont trigger (converting AR relation to array)
    
    if User.current.privilege?(:create_tags)
      tags_to_be_added.each do |new_tag|
        next if tag_list.any? { |tag_in_db| tag_in_db.name.casecmp(new_tag) == 0 }
        missing_tags << new_tag
      end
      missing_tags.each { |tag_name| tag_list.push(self.create(name: tag_name))}
    end
    
    tag_list.compact
  end

  def to_rmq_json
    {
      "id"         => id,
      "account_id" => account_id
    }
  end

  def to_indexed_json
    as_json({
            :root => "helpdesk/tag",
            :tailored_json => true,
            :only => [ :name, :tag_uses_count, :account_id ]
            }).to_json
  end
  
  def to_esv2_json
    as_json({
        root: false,
        tailored_json: true,
        only: [ :name, :tag_uses_count, :account_id ]
      }).to_json
  end

  def to_mob_json
    options = { 
      :only => [:id, :name]
    }
    as_json(options)
  end

  def model_changes
      @model_changes ||= {}
  end
  
  private

    def save_deleted_tag_info
      @deleted_model_info = central_publish_payload
    end

    def save_model_changes
      @model_changes = self.changes.to_hash
    end
    
    def update_taggables
      SearchV2::IndexOperations::UpdateTaggables.perform_async({ :tag_id => self.id }) if Account.current.features_included?(:es_v2_writes)
      CountES::IndexOperations::UpdateTaggables.perform_async(tag_id: self.id)
      CentralPublish::UpdateTaggables.perform_async({ :tag_id => self.id, :changes => @model_changes })
    end
    
    def remove_taguses
      args = { tag_id: id, tag_name: name }
      args[:doer_id] = User.current.id if User.current
      TagUsesCleaner.perform_async(args)
    end
end
