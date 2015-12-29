# encoding: utf-8
class User < ActiveRecord::Base

  # Trigger push to ES only if ES fields updated
  #
  def esv2_fields_updated?
    (@all_changes.keys & esv2_columns).any?
  end

  # Custom json used by ES v2
  #
  def to_esv2_json
    as_json({
              root: false,
              tailored_json: true,
              only: [ :name, :created_at, :updated_at, :account_id, :active, 
                      :job_title, :phone, :mobile, :twitter_id, 
                      :description, :time_zone, :deleted, :fb_profile_id, :language, 
                      :blocked, :address, :helpdesk_agent ], 
              methods: [ :company_name, :emails, :company_id, :tag_ids ]
            }, true).merge(esv2_custom_attributes).merge(tag_names: es_tag_names).to_json
  end

  # Flexifield denormalized
  #
  def esv2_custom_attributes
    flexifield.as_json(root: false, only: esv2_contact_field_data_columns)
  end

  def company_name
    company.name
  end

  def emails
    user_emails.pluck(:email)
  end

  # Renamed as es_tag_names as tag_names already exists
  #
  def es_tag_names
    tags.map(&:name)
  end

  def tag_ids
    tags.map(&:id)
  end

  ##########################
  ### V1 Cluster methods ###
  ##########################
  
  # _Note_: Will be deprecated and remove in near future
  #
  def search_fields_updated?
    (@all_changes.keys & es_columns).any?
  end
  
  # _Note_: Will be deprecated and remove in near future
  # Rename to v2 & remove alias if not changed
  #
  def es_columns
    @@es_columns ||= [:name, :email, :description, :job_title, :phone, :mobile, :twitter_id, 
      :fb_profile_id, :customer_id, :deleted, :helpdesk_agent].concat(es_contact_field_data_columns)
  end

  # _Note_: Will be deprecated and remove in near future
  # Rename to v2 & remove alias if not changed
  #
  def es_contact_field_data_columns
    @@es_contact_field_data_columns ||= ContactFieldData.column_names.select{ |column_name| 
                                    column_name =~ /^cf_(str|text|int|decimal|date)/}.map &:to_sym
  end

  # _Note_: Will be deprecated and remove in near future
  #
  def to_indexed_json
    as_json({
              root: 'user',
              tailored_json: true,
              only: [ :name, :email, :description, :job_title, :phone, :mobile,
                         :twitter_id, :fb_profile_id, :account_id, :deleted,
                         :helpdesk_agent, :created_at, :updated_at ], 
              include: { customer: { only: [:name] },
                            user_emails: { only: [:email] }, 
                            flexifield: { only: es_contact_field_data_columns } } }, true
           ).to_json
  end

  # Remove alias and define if different for V2
  # Keeping it at last for defining after function defined
  #
  alias :esv2_contact_field_data_columns :es_contact_field_data_columns
  alias :esv2_columns :es_columns

end