class Helpdesk::TagUse < ActiveRecord::Base
  self.table_name =  "helpdesk_tag_uses"
  self.primary_key = :id

  concerned_with :presenter


  belongs_to_account
  belongs_to :tags, 
    :class_name => 'Helpdesk::Tag',
    :foreign_key => 'tag_id',
    :counter_cache => true

  belongs_to :taggable, :polymorphic => true
  attr_protected :taggable_id, :taggable_type
  before_create :set_account_id
  before_save :fix_counter_cache
  before_save :save_model_changes, on: :update
  before_destroy :save_deleted_tag_use_info

  publishable
  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher

  validates_uniqueness_of :tag_id, :scope => [:taggable_id, :taggable_type]
  validates_numericality_of :tag_id, :taggable_id

  scope :tags_to_remove, ->(taggable_id,tag_id, taggable_type){
    where({:taggable_id => taggable_id, :tag_id => tag_id, :taggable_type => taggable_type})
  }

  scope :tags_count, ->(tag_id, taggable_type){
    where({:tag_id => tag_id, :taggable_type => taggable_type})
  }

  private

    def save_deleted_tag_use_info
      @deleted_model_info = central_publish_payload
    end

    def save_model_changes
      @model_changes = self.changes.to_hash
    end

    def to_rmq_json
      {
        "id"            => id,
        "tag_id"        => tag_id,
        "taggable_id"   => taggable_id,
        "account_id"    => account_id,
        "taggable_type" => taggable_type
      }
    end

  	def set_account_id
    	self.account_id = tags.account_id
    end

    def fix_counter_cache
      if !self.new_record? && self.tag_id_changed?
      Helpdesk::Tag.decrement_counter(:tag_uses_count, self.tag_id_was)
      Helpdesk::Tag.increment_counter(:tag_uses_count, self.tag_id)
      end
    end

end
