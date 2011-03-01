class Helpdesk::TagUse < ActiveRecord::Base
  set_table_name "helpdesk_tag_uses"

  belongs_to :tags, 
    :class_name => 'Helpdesk::Tag',
    :foreign_key => 'tag_id',
    :counter_cache => true

  belongs_to :taggable, :polymorphic => true
  attr_protected :taggable_id, :taggable_type

  validates_uniqueness_of :tag_id, :scope => [:taggable_id, :taggable_type]
  validates_numericality_of :tag_id, :taggable_id
  
end
