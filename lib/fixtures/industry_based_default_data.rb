class Fixtures::IndustryBasedDefaultData

  DEFAULT_INDUSTRY = "ecommerce"

  def populate(industry)
    industry_mapped = INDUSTRY_MAPPING.fetch(industry, DEFAULT_INDUSTRY)
    Fixtures::DefaultTickets.new(industry_mapped).generate
    Fixtures::DefaultSolutions.new(industry_mapped).generate
  end
end