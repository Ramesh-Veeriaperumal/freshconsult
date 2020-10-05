class Company < ActiveRecord::Base

  # Trigger push to ES only if ES fields updated
  #
  def esv2_fields_updated?
    @model_changes = map_company_custom_field_name_to_column_name
    (@model_changes.keys & esv2_columns).any?
  end

  # Custom json used by ES v2
  #
  def to_esv2_json
    as_json({
              root: false,
              tailored_json: true,
              only: [ :name, :account_id, :created_at, :updated_at, :note ],
              methods: [ :company_description ]
            }).merge(esv2_custom_attributes)
              .merge(esv2_tam_attributes)
              .merge(domains: es_domains).to_json
  end

  # V2 columns to be observed for changes
  #
  def esv2_columns
    @@esv2_columns ||= [:description, :domains, :name, :note,
                        :string_cc01, :string_cc02, :string_cc03,
                        :datetime_cc01].concat(esv2_company_field_data_columns)
  end
  
  # V2 custom field columns
  #
  def esv2_company_field_data_columns
    @@esv2_company_field_data_columns ||= CompanyFieldData.column_names.select{ 
                                            |column_name| column_name =~ /^cf_/
                                          }.map(&:to_sym)
  end

  # Flexifield denormalized
  #
  def esv2_custom_attributes
    flexifield.as_json(root: false, only: esv2_company_field_data_columns)
  end

  def esv2_tam_attributes
    {
      health_score: flexifield.string_cc01,
      account_tier: flexifield.string_cc02,
      industry: flexifield.string_cc03,
      renewal_date: flexifield.datetime_cc01
    }
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

  def map_company_custom_field_name_to_column_name
    changes = @model_changes
    company_custom_field_column_name_mapping = account.company_form.company_fields_from_cache.each_with_object({}) do |entry, hash|
      hash[entry.name] = entry.column_name
    end
    company_custom_field_column_name_mapping.keys.each do |key|
      if changes.key?(key)
        changes[company_custom_field_column_name_mapping[key]] = changes[key]
        changes.delete(key)
      end
    end
    changes.symbolize_keys!
  end
  
  # _Note_: Will be deprecated and remove in near future
  #
  def self.es_filter(account_id, letter,page, field_name, sort_order, per_page, uuid)
    Search::V2::QueryHandler.new(
      {
        account_id:   account_id,
        context:      :company_v2_search,
        exact_match:  false,
        es_models:    { 'company' => { model: 'Company', associations: [:flexifield, :company_domains] } },
        current_page: page,
        offset:       per_page * (page.to_i - 1),
        types:        ['company'],
        es_params:    ({
          search_term: letter ? letter.downcase : nil,
          account_id: account_id,
          request_id: uuid,
          size: per_page,
          offset: per_page * (page.to_i - 1),
          from: per_page * (page.to_i - 1) # offset should be removed once all the accounts migrated to Service
        })
      }
    ).query_results
  end

  alias_attribute :company_description, :description
  
end