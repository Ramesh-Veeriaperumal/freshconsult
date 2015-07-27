class Company < ActiveRecord::Base
   
  def to_indexed_json
    as_json( 
              :root => "customer",
              :tailored_json => true,
              :only => [ :name, :note, :description, :account_id, :created_at, :updated_at ],
              :include => { :flexifield => { :only => es_company_field_data_columns } }
           ).to_json
  end

  def es_company_field_data_columns
    @@es_company_field_data_columns ||= CompanyFieldData.column_names.select{ |column_name| 
                                      column_name =~ /^cf_(str|text|int|decimal|date)/}.map &:to_sym
  end

  def es_columns
    @@es_columns ||= [:name, :description, :note].concat(es_company_field_data_columns)
  end
  
  # May not need this after ES re-indexing
  def self.document_type # Required to override the model name
    'customer'
  end

  def document_type # Required to override the model name
    'customer'
  end
  
end