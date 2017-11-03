account = Account.current

COMPANY_FIELDS =
  [
    { :name               => "description", 
      :label              => "Description",
      :position           => 2 },

    { :name               => "note", 
      :label              => "Notes",
      :position           => 3 },

    { :name               => "domains", 
      :label              => "Domain Names for this company",
      :position           => 4 },

    { :name               => "health_score",
      :label              => "Health score",
      :position           => 5 },

    { :name               => "account_tier",
      :label              => "Account tier",
      :position           => 6 },

    { :name               => "renewal_date",
      :label              => "Renewal date",
      :position           => 7 },

    { :name               => "industry", 
      :label              => "Industry",
      :position           => 8 }
  ]

DEFAULT_ACCOUNT_TIER_VALUES = 
  [
    { :value     => "Platinum" },
    { :value     => "Gold" },
    { :value     => "Silver" }
  ]

DEFAULT_HEALTH_SCORE_VALUES = 
  [
    { :value     => "At risk" },
    { :value     => "Pretty OK" },
    { :value     => "Happy" }
  ]

DEFAULT_INDUSTRY_VALUES = 
  [
    { :value     => "Automotive" },
    { :value     => "Consumer Durables & Apparel" },
    { :value     => "Diversified Consumer Services" },
    { :value     => "Hotels, Restaurants & Leisure" },
    { :value     => "Consumer Goods" },
    { :value     => "Household Durables" },
    { :value     => "Leisure Products" },
    { :value     => "Textiles, Apparel & Luxury Goods" },
    { :value     => "Education Services" },
    { :value     => "Family Services" },
    { :value     => "Specialized Consumer Services" },
    { :value     => "Media" },
    { :value     => "Distributors" },
    { :value     => "Specialty Retail" },
    { :value     => "Beverages" },
    { :value     => "Food Products" },
    { :value     => "Food & Staples Retailing" },
    { :value     => "Personal Products" },
    { :value     => "Tobacco" },
    { :value     => "Gas Utilities" },
    { :value     => "Banks" },
    { :value     => "Capital Markets" },
    { :value     => "Diversified Financial Services" },
    { :value     => "Insurance" },
    { :value     => "Real Estate" },
    { :value     => "Health Care Equipment & Supplies" },
    { :value     => "Health Care Providers & Services" },
    { :value     => "Biotechnology" },
    { :value     => "Pharmaceuticals" },
    { :value     => "Professional Services" },
    { :value     => "Aerospace & Defense" },
    { :value     => "Air Freight & Logistics" },
    { :value     => "Airlines" },
    { :value     => "Commercial Services & Supplies" },
    { :value     => "Construction & Engineering" },
    { :value     => "Electrical Equipment" },
    { :value     => "Industrial Conglomerates" },
    { :value     => "Machinery" },
    { :value     => "Marine" },
    { :value     => "Road & Rail" },
    { :value     => "Trading Companies & Distributors" },
    { :value     => "Transportation" },
    { :value     => "Internet Software & Services" },
    { :value     => "IT Services" },
    { :value     => "Software" },
    { :value     => "Communications Equipment" },
    { :value     => "Electronic Equipment, Instruments & Components" },
    { :value     => "Technology Hardware, Storage & Peripherals" },
    { :value     => "Building Materials" },
    { :value     => "Chemicals" },
    { :value     => "Containers & Packaging" },
    { :value     => "Metals & Mining" },
    { :value     => "Paper & Forest Products" },
    { :value     => "Diversified Telecommunication Services" },
    { :value     => "Wireless Telecommunication Services" },
    { :value     => "Renewable Electricity" },
    { :value     => "Electric Utilities" },
    { :value     => "Utilities" },
    { :value     => "Other" }
  ]

FIELDS_WITH_CHOICES = ['health_score', 'account_tier', 'industry']

def self.company_fields_data
  COMPANY_FIELDS.each_with_index.map do |f, i|
    {
      :name               => f[:name],
      :column_name        => 'default',
      :label              => f[:label],
      :deleted            => false,
      :field_type         => :"default_#{f[:name]}",
      :position           => f[:position],
      :required_for_agent => f[:required_for_agent] || 0,
      :field_options      => f[:field_options] || {},
    }
  end
end

def self.account_tier_data
  DEFAULT_ACCOUNT_TIER_VALUES.each_with_index.map do |f, i|
    {
      :name               => f[:value],
      :value              => f[:value],
      :position           => i + 1,
      :_destroy            => 0
    }
  end
end

def self.industry_data
  DEFAULT_INDUSTRY_VALUES.each_with_index.map do |f, i|
    {
      :name               => f[:value],
      :value              => f[:value],
      :position           => i + 1,
      :_destroy            => 0
    }
  end
end

def self.health_score_data
  DEFAULT_HEALTH_SCORE_VALUES.each_with_index.map do |f, i|
    {
      :name               => f[:value],
      :value              => f[:value],
      :position           => i + 1,
      :_destroy            => 0
    }
  end
end

company_fields_data.each do |field_data|
  field_name = field_data.delete(:name)
  column_name = field_data.delete(:column_name)
  deleted = field_data.delete(:deleted)
  if FIELDS_WITH_CHOICES.include?(field_name)
    field_data[:custom_field_choices_attributes] = send("#{field_name}_data") 
  end
  company_field = CompanyField.new(field_data)

  # The following are attribute protected.
  company_field.column_name = column_name
  company_field.name = field_name
  company_field.deleted = deleted
  company_field.company_form_id = account.company_form.id
  company_field.save
end
account.company_form.clear_cache
