class Helpdesk::TagUse < ActiveRecord::Base
  self.table_name =  "helpdesk_tag_uses"
  self.primary_key = :id

  belongs_to_account
  belongs_to :tags, 
    :class_name => 'Helpdesk::Tag',
    :foreign_key => 'tag_id',
    :counter_cache => true

  belongs_to :taggable, :polymorphic => true
  attr_protected :taggable_id, :taggable_type
  before_create :set_account_id
  before_save :fix_counter_cache

  validates_uniqueness_of :tag_id, :scope => [:taggable_id, :taggable_type]
  validates_numericality_of :tag_id, :taggable_id

  scope :tags_to_remove, lambda { |taggable_id,tag_id,taggable_type|
          { 
            :conditions => {:taggable_id => taggable_id, :tag_id => tag_id, :taggable_type => taggable_type}
          }
        }

  private
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
