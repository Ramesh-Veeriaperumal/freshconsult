class Social::Stream < ActiveRecord::Base

  set_table_name "social_streams"
  belongs_to_account

  serialize :data, Hash
  serialize :includes, Array
  serialize :excludes, Array
  serialize :filter, Hash

  validates_presence_of :account_id

  has_many :ticket_rules,
    :class_name => 'Social::TicketRule',
    :foreign_key => :stream_id,
    :dependent => :destroy,
    :order => :position

  def search_keys_to_s
    includes.blank? ? "" : includes.join(",")
  end

  def excludes_to_s
    excludes.blank? ? "" : excludes.join(",")
  end
end
