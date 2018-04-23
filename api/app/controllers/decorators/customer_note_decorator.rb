class CustomerNoteDecorator < ApiDecorator
  delegate :id, :title, :body, :created_by_name, :last_updated_by_name, :user_id, :company_id,
           :category_id, :attachments, :s3_url, :s3_key?, to: :record, allow_nil: true
  delegate :customer_notes_s3_enabled?, to: 'Account.current'

  def initialize(record, options)
    super(record)
    @name_mapping = options[:name_mapping]
  end

  def to_hash
    response_hash = {
      id: id,
      title: title,
      created_by: created_by_name,
      last_updated_by: last_updated_by_name,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      attachments: attachments.map { |att| AttachmentDecorator.new(att).to_hash }
    }

    if s3_key? && customer_notes_s3_enabled?
      response_hash[:s3_url] = s3_url
    else
      response_hash[:body] = body
    end

    if record.instance_of?(CompanyNote)
      response_hash[:company_id] = company_id
      response_hash[:category_id] = category_id
    end
    response_hash[@name_mapping[:user_id]] = user_id if record.instance_of?(ContactNote)
    response_hash
  end
end
