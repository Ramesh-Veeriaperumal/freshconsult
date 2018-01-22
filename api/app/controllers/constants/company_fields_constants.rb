module CompanyFieldsConstants


  NEW_DEFAULT_FIELDS = [ :default_health_score, :default_account_tier,
                        :default_renewal_date, :default_industry ].freeze
  ACCOUNT_TIER_CHOICES = ["Basic", "Premium", "Enterprise"]
  HEALTH_SCORE_CHOICES = ["At risk", "Doing okay", "Happy"]
  INDUSTRY_CHOICES = ["Automotive", "Consumer Durables & Apparel",
                      "Diversified Consumer Services", "Hotels, Restaurants & Leisure",
                      "Consumer Goods", "Household Durables", "Leisure Products",
                      "Textiles, Apparel & Luxury Goods", "Education Services",
                      "Family Services", "Specialized Consumer Services",
                      "Media", "Distributors", "Specialty Retail", "Beverages",
                      "Food Products", "Food & Staples Retailing", "Personal Products",
                      "Tobacco", "Gas Utilities", "Banks",  "Capital Markets",
                      "Diversified Financial Services", "Insurance",  "Real Estate",
                      "Health Care Equipment & Supplies", "Health Care Providers & Services",
                      "Biotechnology", "Pharmaceuticals", "Professional Services",
                      "Aerospace & Defense", "Air Freight & Logistics", "Airlines",
                      "Commercial Services & Supplies", "Construction & Engineering",
                      "Electrical Equipment", "Industrial Conglomerates",
                      "Machinery", "Marine", "Road & Rail", "Trading Companies & Distributors",
                      "Transportation", "Internet Software & Services", "IT Services",
                      "Software", "Communications Equipment",
                      "Electronic Equipment, Instruments & Components",
                      "Technology Hardware, Storage & Peripherals",
                      "Building Materials", "Chemicals", "Containers & Packaging",
                      "Metals & Mining", "Paper & Forest Products",
                      "Diversified Telecommunication Services",
                      "Wireless Telecommunication Services",
                      "Renewable Electricity", "Electric Utilities",
                      "Utilities", "Other"]

  TAM_FIELDS_EN_KEYS_MAPPING = begin
    key_value_map = {}
    (ACCOUNT_TIER_CHOICES).each_with_index do |choice, index|
      key_value_map["tam_fields.account_tier.default_choice#{index}"] = choice
    end
    (HEALTH_SCORE_CHOICES).each_with_index do |choice, index|
      key_value_map["tam_fields.health_score.default_choice#{index}"] = choice
    end
    (INDUSTRY_CHOICES).each_with_index do |choice, index|
      key_value_map["tam_fields.industry.default_choice#{index}"] = choice
    end
    key_value_map
  end

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

  FIELDS_WITH_CHOICES = ['health_score', 'account_tier', 'industry']


  TAM_FIELDS = COMPANY_FIELDS[3..-1].map { |f| f.except(:position) }


  TAM_FIELDS_DATA = {
    "account_tier_data" => ACCOUNT_TIER_CHOICES.each_with_index.map do |value, i|
                             {
                                :name               => value,
                                :value              => value,
                                :position           => i + 1,
                                :_destroy            => 0
                             }
                           end,

    "industry_data"    => HEALTH_SCORE_CHOICES.each_with_index.map do |value, i|
                            {
                              :name               => value,
                              :value              => value,
                              :position           => i + 1,
                              :_destroy            => 0
                            }
                          end,

    "health_score_data" => INDUSTRY_CHOICES.each_with_index.map do |value, i|
                            {
                              :name               => value,
                              :value              => value,
                              :position           => i + 1,
                              :_destroy            => 0
                            }
                           end
  }

  def self.company_fields_data(account = nil, fields = COMPANY_FIELDS)
    unless account.nil?
      existing_fields_count = account.company_form.fields.length
      fields = TAM_FIELDS
    end
    fields.each_with_index.map do |f, i|
      {
        :name               => f[:name],
        :column_name        => 'default',
        :label              => f[:label],
        :deleted            => false,
        :field_type         => :"default_#{f[:name]}",
        :position           => f[:position] || existing_fields_count + i + 1,
        :required_for_agent => f[:required_for_agent] || 0,
        :field_options      => f[:field_options] || {}
      }
    end
  end 
end