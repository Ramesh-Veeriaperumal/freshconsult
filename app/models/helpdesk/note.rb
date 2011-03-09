class Helpdesk::Note < ActiveRecord::Base
  set_table_name "helpdesk_notes"

  belongs_to :notable, :polymorphic => true

  belongs_to :user

  has_many :attachments,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy

  attr_accessor :nscname
  
  #attr_accessible :body,:private  
  
  after_create :save_response_time

  named_scope :newest_first, :order => "created_at DESC"
  named_scope :visible, :conditions => { :deleted => false } 
  named_scope :public, :conditions => { :private => false } 

  named_scope :freshest, lambda { |account|
    { :conditions => ["deleted = ? and account_id = ? ", false, account], 
      :order => "helpdesk_notes.created_at DESC"
    }
  }


  SOURCES = %w{email form note status meta}
  SOURCE_KEYS_BY_TOKEN = Hash[*SOURCES.zip((0..SOURCES.size-1).to_a).flatten]

  named_scope :exclude_source, lambda { |s| { :conditions => ['source <> ?', SOURCE_KEYS_BY_TOKEN[s]] } }

  validates_presence_of :body, :source, :notable_id
  validates_numericality_of :source
  validates_inclusion_of :source, :in => 0..SOURCES.size-1

  def status?
    source == SOURCE_KEYS_BY_TOKEN["status"]
  end
  
  def email?
    source == SOURCE_KEYS_BY_TOKEN["email"]
  end
  
  def to_liquid
    { "commenter"   => user,
      "body"     => body }
  end
  
  def save_response_time
    
    if ((self.notable.is_a? Helpdesk::Ticket) && user)    
        ticket_state = notable.ticket_states     
        if "Customer".eql?(User::USER_ROLES_NAMES_BY_KEY[user.user_role])      
          ticket_state.requester_responded_at=Time.zone.now          
        else
          ticket_state.agent_responded_at=Time.zone.now unless private
          ticket_state.first_response_time=Time.zone.now if ticket_state.first_response_time.nil? && !private
      end  
      ticket_state.save
    end
    
  end

end
