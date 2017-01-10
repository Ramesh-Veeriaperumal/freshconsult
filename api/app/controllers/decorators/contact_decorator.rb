class ContactDecorator < ApiDecorator
  delegate  :id, :active, :address, :deleted, :description,
            :customer_id, :email, :job_title, :language, :mobile,
            :name, :phone, :time_zone, :twitter_id, :avatar, to: :record
  delegate :company_id, :client_manager, to: :default_company, allow_nil: true
  delegate :multiple_user_companies_enabled?, to: 'Account.current'

  def initialize(record, options)
    super(record)
    @name_mapping = options[:name_mapping]
  end

  def tags
    record.tags.map(&:name)
  end

  def custom_fields
    # @name_mapping will be nil for READ requests
    custom_fields_hash = {}
    record.custom_field.each { |k, v| custom_fields_hash[@name_mapping[k]] = v }
    custom_fields_hash
  end

  def other_emails
    record.user_emails.reject(&:primary_role).map(&:email)
  end

  def default_company
    @default_company = record.default_user_company
  end

  def other_companies
    others = record.user_companies - [default_company]
    others.map{|x| {company_id: x.company_id, view_all_tickets: x.client_manager}}
  end

end
