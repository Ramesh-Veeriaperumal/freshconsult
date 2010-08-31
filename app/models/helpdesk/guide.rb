class Helpdesk::Guide < ActiveRecord::Base
  set_table_name "helpdesk_guides"

  has_many :article_guides,
    :class_name => 'Helpdesk::ArticleGuide'

  has_many :articles, 
    :class_name => 'Helpdesk::Article',
    :through => :article_guides

  named_scope :most_used_first, :order => 'article_guides_count DESC' 
  named_scope :alphabetical, :order => 'name ASC' 
  named_scope :display_order, :order => 'position ASC' 
  named_scope :visible, :conditions => {:hidden => false}

  validates_presence_of :name
  validates_length_of :name, :in => 2..240

  def to_param
    id ? "#{id}-#{name.downcase.gsub(/[^a-z0-9]+/i, '-')}" : nil
  end

  def nickname
    name
  end

end
