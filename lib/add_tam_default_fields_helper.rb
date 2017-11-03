module AddTamDefaultFieldsHelper

  NEW_DEFAULT_FIELDS = [ :default_health_score, :default_account_tier,
                        :default_renewal_date, :default_industry ]

  DEFAULT_FIELDS =
    [
      { :name               => "health_score", 
        :label              => "Health score"},

      { :name               => "account_tier", 
        :label              => "Account tier" },

      { :name               => "renewal_date", 
        :label              => "Renewal date" },

      { :name               => "industry", 
        :label              => "Industry" }
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

  def populate_tam_fields_data
    begin
      company_fields_data(account).each do |field_data|
        field_name = field_data.delete(:name)
        column_name = field_data.delete(:column_name)
        deleted = field_data.delete(:deleted)
        unless field_name == "renewal_date"
          field_data[:custom_field_choices_attributes] = send("#{field_name}_data") 
        end
        field = CompanyField.new(field_data)
        field.name = field_name
        field.column_name = column_name
        field.deleted = deleted
        field.company_form_id = account.company_form.id
        field.save
      end
    rescue => e
      Rails.logger.info("Something went wrong while adding the CSM default fields")
      NewRelic::Agent.notice_error(e)
      raise e
    ensure
      account.company_form.clear_cache
    end
  end

  def account
    Account.current
  end

  def company_fields_data account
    existing_fields_count = account.company_form.fields.length
    DEFAULT_FIELDS.each_with_index.map do |f, i|
      {
        :name               => f[:name],
        :column_name        => 'default',
        :label              => f[:label],
        :deleted            => 0,
        :field_type         => :"default_#{f[:name]}",
        :position           => existing_fields_count + i + 1,
        :required_for_agent => f[:required_for_agent] || 0,
        :field_options      => f[:field_options] || {},
      }
    end
  end

  def account_tier_data
    DEFAULT_ACCOUNT_TIER_VALUES.each_with_index.map do |f, i|
      {
        :name               => f[:value],
        :value              => f[:value],
        :position           => i + 1,
        :_destroy            => 0
      }
    end
  end

  def industry_data
    DEFAULT_INDUSTRY_VALUES.each_with_index.map do |f, i|
      {
        :name               => f[:value],
        :value              => f[:value],
        :position           => i + 1,
        :_destroy            => 0
      }
    end
  end

  def health_score_data
    DEFAULT_HEALTH_SCORE_VALUES.each_with_index.map do |f, i|
      {
        :name               => f[:value],
        :value              => f[:value],
        :position           => i + 1,
        :_destroy            => 0
      }
    end
  end
end