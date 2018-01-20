class TodoDecorator < ApiDecorator
  delegate :id, :body, :deleted, :user_id, :created_at, :updated_at, 
    :contact_id, :company_id, :rememberable_attribute, to: :record

  def initialize(record, options)
    super
    @options = options
  end

  def to_hash
    {
      id: id,
      body: body,
      completed: deleted,
      user_id: user_id,
      contact_id: contact_id,
      ticket_id: rememberable_attribute("display_id", @options[:ticket],  
        "ticket"),
      ticket_subject: rememberable_attribute("subject", @options[:ticket], 
        "ticket"),
      contact_name: rememberable_attribute("name", @options[:contact], 
        "contact"),
      company_id: company_id,
      company_name: rememberable_attribute("name", @options[:company], 
        "company"),
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }
  end

end
