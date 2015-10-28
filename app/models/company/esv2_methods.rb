class Company < ActiveRecord::Base

  # Trigger push to ES only if ES fields updated
  #
  def esv2_fields_updated?
    (@model_changes.keys & esv2_columns).any?
  end

  # Custom json used by ES v2
  # To-do: Change based on mappings
  #
  def to_esv2_json
    as_json({
              root: false,
              tailored_json: true,
              only: [ :name, :account_id, :description, :created_at, :updated_at, :note ]
            }).merge(esv2_custom_attributes)
              .merge(domains: es_domains).to_json
  end

  # V2 columns to be observed for changes
  #
  def esv2_columns
    @@esv2_columns ||= [:name, :note, :description].merge(esv2_company_field_data_columns)
  end

  # Flexifield denormalized
  #
  def esv2_custom_attributes
    flexifield.as_json(root: false, only: esv2_company_field_data_columns)
  end

  # Replace with company-domains when it comes
  #
  def es_domains
    domains.to_s.split(',').map(&:strip).reject(&:empty?)
  end

  ##########################
  ### V1 Cluster methods ###
  ##########################
   
  # _Note_: Will be deprecated and remove in near future
  #
  def to_indexed_json
    as_json( 
              :root => "customer",
              :tailored_json => true,
              :only => [ :name, :note, :description, :account_id, :created_at, :updated_at ],
              :include => { :flexifield => { :only => es_company_field_data_columns } }
           ).to_json
  end

  # _Note_: Will be deprecated and remove in near future
  #
  def es_company_field_data_columns
    @@es_company_field_data_columns ||= CompanyFieldData.column_names.select{ |column_name| 
                                      column_name =~ /^cf_(str|text|int|decimal|date)/}.map &:to_sym
  end

  # _Note_: Will be deprecated and remove in near future
  #
  def es_columns
    @@es_columns ||= [:name, :description, :note].concat(es_company_field_data_columns)
  end
  
  # _Note_: Will be deprecated and remove in near future
  # May not need this after ES re-indexing
  #
  def self.document_type # Required to override the model name
    'customer'
  end

  # _Note_: Will be deprecated and remove in near future
  #
  def document_type # Required to override the model name
    'customer'
  end

  # _Note_: Will be deprecated and remove in near future
  #
  def search_fields_updated?
    (@model_changes.keys & es_columns).any?
  end

  # Remove alias and define if different for V2
  # Keeping it at last for defining after function defined
  #
  alias :esv2_company_field_data_columns :es_company_field_data_columns
  
end