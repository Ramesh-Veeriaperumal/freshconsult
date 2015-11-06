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
  
  # _Note_: Will be deprecated and remove in near future
  #
  def self.es_filter(account_id, letter,page, field_name, sort_order, per_page)
    Search::EsIndexDefinition.es_cluster(account_id)
    index_name = Search::EsIndexDefinition.searchable_aliases([Customer], account_id)
    options = {:load => { Company => { :include => [:flexifield] }} , :page => page, :size => per_page, :preference => :_primary_first }
    items = Tire.search(index_name, options) do |search|
      search.query do |query|
        query.filtered do |f|
          if(letter)
            f.query { |q| q.string SearchUtil.es_filter_key(letter) }
          else
            f.query { |q| q.string '*' }
          end
          f.filter :term, { :account_id => account_id }
        end
      end
      search.from options[:size].to_i * (options[:page].to_i-1)
      search.sort { by field_name, sort_order } 
    end
    search_results = []
    items.results.each_with_hit do |result, hit|
      search_results.push(result)
    end
    search_results
  end

  # Remove alias and define if different for V2
  # Keeping it at last for defining after function defined
  #
  alias :esv2_company_field_data_columns :es_company_field_data_columns
  
end