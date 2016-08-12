module CustomerDeprecationMethods

  def self.included(base)
    base.send(:include, BelongsTo) if base.reflect_on_association(:company)
    base.send(:include, HasMany)   if base.reflect_on_association(:companies)
  end

  module BelongsTo
    def self.included(base)
      base.alias_attribute :company_id, :customer_id
      base.belongs_to :customer, :class_name => 'Company', :foreign_key => 'customer_id'
      # should remove the association once the ES re-indexing is done
      base.alias_method_chain :customer, :deprecation_warning
      base.alias_method_chain :customer=, :deprecation_warning
    end

    def customer_with_deprecation_warning
      warn :"[DEPRECATION WARNING] Use 'company' instead of 'customer'"
      company
    end

    def customer_with_deprecation_warning= company
      warn :"[DEPRECATION WARNING] Use 'company=' instead of 'customer='"
      self.company = company
    end
  end

  module HasMany
    def self.included(base)
      base.has_many :customers, :class_name => 'Company'
      base.alias_method_chain :customers, :deprecation_warning
      base.alias_method_chain :customers=, :deprecation_warning
    end

    def customers_with_deprecation_warning
      warn :"[DEPRECATION WARNING] Use 'companies' instead of 'customers'"
      companies
    end

    def customers_with_deprecation_warning= companies
      warn :"[DEPRECATION WARNING] Use 'companies=' instead of 'customers='"
      self.companies = companies
    end
  end

  module NormalizeParams
    # Preferring one key over other is the reason for same key,value and its order 
    ATTRIBUTE_MAP = { 
      :company_name  => :company_name,
      :customer      => :company_name,
      :company_id    => :company_id,
      :customer_id   => :company_id,
      :customer_name => :company_name
    }

    # hack to facilitate contact_fields & deprecate customer
    def normalize_params parameters=params  # params in default value refers to controller params
      attribute = ATTRIBUTE_MAP.keys.find do |attr|
        parameters.include?(attr)
      end
      unless attribute.nil?
        attribute_to_store = ATTRIBUTE_MAP[attribute]
        parameters[attribute_to_store] =  parameters[attribute]
      end
    end
  end

end