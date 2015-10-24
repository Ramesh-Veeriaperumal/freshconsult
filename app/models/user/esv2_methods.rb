# encoding: utf-8
class User < ActiveRecord::Base

  # Trigger push to ES only if ES fields updated
  #
  def esv2_fields_updated?
    (@all_changes.keys & esv2_columns).any?
  end

  # Custom json used by ES v2
  # To-do: Change based on mappings
  #
  def to_esv2_json
    as_json({
              root: false,
              tailored_json: true,
              only: [ :name, :email, :description, :job_title, :phone, :mobile,
                         :twitter_id, :fb_profile_id, :account_id, :deleted,
                         :helpdesk_agent, :created_at, :updated_at ], 
              include: { customer: { only: [:name] },
                            user_emails: { only: [:email] }, 
                            flexifield: { only: esv2_contact_field_data_columns }}
            }, true).to_json
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