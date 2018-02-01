class Helpdesk::Reminder < ActiveRecord::Base
  self.table_name =  "helpdesk_reminders"
  self.primary_key = :id

  belongs_to_account
  belongs_to :user, class_name: 'User'
  belongs_to :ticket, class_name: 'Helpdesk::Ticket'
  belongs_to :contact, class_name: 'User', foreign_key: 'contact_id', 
    inverse_of: :contact_reminders
  belongs_to :company, class_name: 'Company', foreign_key: 'company_id', 
    inverse_of: :reminders

  scope :visible, :conditions => [ "deleted = ?", false ], 
    :order => 'updated_at ASC, created_at ASC'
  scope :logged, lambda { |time| 
          { 
            :conditions => ["deleted = ? AND updated_at > ?", true, time], 
            :order => 'deleted ASC, updated_at DESC, created_at DESC'  
          }
        }
  scope :with_resources, lambda { |resources|
                          self.preload(*resources).order("id DESC")
                        }
  attr_accessible :body, :deleted, :user
  
  validates_numericality_of :user_id
  validates_presence_of :body
  validates_length_of :body, :in => 1..TodoConstants::MAX_LENGTH_OF_TODO_CONTENT

  before_create :set_account_id

  def rememberable_type
    @type ||= begin
      rememberable_map = TodoConstants::REMEMBERABLE_FIELD_MAP.select do |field_map|
        read_attribute(field_map[1]).present?
      end.first
      rememberable_map && rememberable_map[0]  
    end
  end

  def rememberable_attribute(attribute, rememberable=nil, association_attr=nil)
    if rememberable.present?
      attribute && rememberable.send(attribute)
    elsif association_attr.present?
      attribute && send(association_attr).try(attribute)
    end
  end

  private
    def set_account_id
      self.account_id = user.account_id
    end
end
