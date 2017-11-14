module CompanyFieldsConstants


  NEW_DEFAULT_FIELDS = [ :default_health_score, :default_account_tier,
                        :default_renewal_date, :default_industry ]

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

  TAM_FIELDS_DATA = {
    "account_tier_data" => DEFAULT_ACCOUNT_TIER_VALUES.each_with_index.map do |f, i|
                             {
                                :name               => f[:value],
                                :value              => f[:value],
                                :position           => i + 1,
                                :_destroy            => 0
                             }
                           end,

    "industry_data"    => DEFAULT_INDUSTRY_VALUES.each_with_index.map do |f, i|
                            {
                              :name               => f[:value],
                              :value              => f[:value],
                              :position           => i + 1,
                              :_destroy            => 0
                            }
                         end,

    "health_score_data" => DEFAULT_HEALTH_SCORE_VALUES.each_with_index.map do |f, i|
                            {
                              :name               => f[:value],
                              :value              => f[:value],
                              :position           => i + 1,
                              :_destroy            => 0
                            }
                          end
  }

end