class NoteDecorator < ApiDecorator
  delegate :id, :incoming, :private, :user_id, :support_email, :to_emails, to: :record

  def body
    record.body_html
  end
  
  def body_text
    record.body
  end
  
  def to_hash
    {
      id: id,
      incoming: incoming,
      private: self.private,
      user_id: user_id,
      support_email: support_email,
      to_emails: to_emails,
      body: body,
      attachments: [] #TODO-EMBERAPI Complete this
    }
  end
end
