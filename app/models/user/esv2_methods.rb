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
                      :time_zone, :deleted, :fb_profile_id, :language, 
                      :blocked, :address, :helpdesk_agent, :unique_external_id ], 
              methods: [:user_description, :company_names, :emails, :company_ids, :tag_ids, :parent_id, :sanitized_mobile, :sanitized_phone]
            }, true).merge(agent_es_attributes).merge(esv2_custom_attributes).merge(tag_names: es_tag_names).to_json
  end
  
  # V2 columns to be observed for changes
  #
  def esv2_columns
    @@esv2_columns ||= [:account_id, :active, :address, :blocked, :deleted, :description, :email,
                        :fb_profile_id, :helpdesk_agent, :job_title, :language, :mobile, :name,
                        :phone, :string_uc04, :time_zone, :twitter_id, :tags, :unique_external_id,
                        :customer_id, :company_ids, :agent_type, :group_ids, :contribution_group_ids].concat(esv2_contact_field_data_columns)
  end
  
  # V2 custom field columns
  #
  def esv2_contact_field_data_columns
    @@esv2_contact_field_data_columns ||= ContactFieldData.column_names.select{
                                            |column_name| column_name =~ /^cf_/
                                          }.map(&:to_sym)
  end

  # Flexifield denormalized
  #
  def esv2_custom_attributes
    flexifield.as_json(root: false, only: esv2_contact_field_data_columns)
  end

  def emails
    user_emails.pluck(:email)
  end

  def agent_es_attributes
    {
      agent_type: agent.try(:agent_type),
      group_ids: agent? ? associated_group_ids : nil,
      contribution_group_ids: agent? ? read_associated_group_ids : nil
    }
  end

  # Renamed as es_tag_names as tag_names already exists
  #
  def es_tag_names
    tags.map(&:name)
  end

  def tag_ids
    tags.map(&:id)
  end

  def sanitized_mobile
    mobile&.gsub(/[^\d]/, '')
  end

  def sanitized_phone
    phone&.gsub(/[^\d]/, '')
  end

  # Tag use callbacks to ES
  def update_user_tags(obj)
    self.tags_updated = true
  end
  def update_user_companies(obj)
    self.user_companies_updated = true
  end

  def update_user_emails(*)
    self.user_emails_updated = true
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
  #
  def es_columns
    @@es_columns ||= [:name, :email, :description, :job_title, :phone, :mobile, :twitter_id, 
      :fb_profile_id, :customer_id, :deleted, :helpdesk_agent].concat(es_contact_field_data_columns)
  end

  # _Note_: Will be deprecated and remove in near future
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

  alias_attribute :user_description, :description

end
