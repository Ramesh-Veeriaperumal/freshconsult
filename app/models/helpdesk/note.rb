class Helpdesk::Note < ActiveRecord::Base
  set_table_name "helpdesk_notes"

  belongs_to :notable, :polymorphic => true  
  belongs_to :account
  belongs_to :user

  has_many :attachments,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy

  attr_accessor :nscname
  attr_protected :attachments, :notable_id
  
  after_create :save_response_time, :update_parent, :add_activity

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
  
  def private_note?
    source == SOURCE_KEYS_BY_TOKEN["note"] && private
  end
  
  def public_note?
    source == SOURCE_KEYS_BY_TOKEN["note"] && !private
  end
  
  def inbound_email?
    source == SOURCE_KEYS_BY_TOKEN["email"] && incoming
  end
  
  def outbound_email?
    source == SOURCE_KEYS_BY_TOKEN["email"] && !incoming
  end
  
  def to_liquid
    { "commenter"   => user,
      "body"     => body }
  end

  protected
    def save_response_time
      if human_note_for_ticket?
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
    
    def update_parent #Maybe after_save?!
      return unless human_note_for_ticket?
      
      if user.customer?
        unless notable.active?
          notable.status = Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open]
          notification_type = EmailNotification::TICKET_REOPENED
        end 
        e_notification = account.email_notifications.find_by_notification_type(notification_type ||= EmailNotification::REPLIED_BY_REQUESTER)
        Helpdesk::TicketNotifier.send_later(:notify_by_email, (notification_type ||= 
              EmailNotification::REPLIED_BY_REQUESTER), notable, self) if notable.responder && e_notification.agent_notification?
      else
        e_notification = account.email_notifications.find_by_notification_type(EmailNotification::COMMENTED_BY_AGENT)
        Helpdesk::TicketNotifier.send_later(:notify_by_email, EmailNotification::COMMENTED_BY_AGENT, 
            notable, self) if source.eql?(SOURCE_KEYS_BY_TOKEN["note"]) && !private && e_notification.requester_notification?
      end
      
      notable.updated_at = created_at
      notable.save
    end
    
    def add_activity
      return unless human_note_for_ticket?
      
      if outbound_email?
        notable.create_activity(user, 'activities.tickets.conversation.out_email.long',
            {'eval_args' => {'reply_path' => ['reply_path', 
                                {'ticket_id' => notable.display_id, 'comment_id' => id}]}},
            'activities.tickets.conversation.out_email.short')
      elsif inbound_email?
        notable.create_activity(user, 'activities.tickets.conversation.in_email.long', 
          {'eval_args' => {'email_response_path' => ['email_response_path', 
                                {'ticket_id' => notable.display_id, 'comment_id' => id}]}},
          'activities.tickets.conversation.in_email.short')
      else
        notable.create_activity(user, 'activities.tickets.conversation.note.long', 
          {'eval_args' => {'comment_path' => ['comment_path', 
                                {'ticket_id' => notable.display_id, 'comment_id' => id}]}},
          'activities.tickets.conversation.note.short')
      end
    end
    
  private
    def human_note_for_ticket?
      (self.notable.is_a? Helpdesk::Ticket) && user && (source != SOURCE_KEYS_BY_TOKEN['meta'])
    end

end
