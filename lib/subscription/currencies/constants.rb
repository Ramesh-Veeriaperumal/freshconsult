module Subscription::Currencies::Constants

  BILLING_CURRENCIES = [ "EUR", "INR", "USD", "ZAR", "GBP", "AUD", "BRL"]
  DEFAULT_CURRENCY = "USD"
  CURRENCY_NOT_SUPPORTED = ["BRL"]
  COUNTRY_MAPPING = 	{
    "INDIA" => "INR",
    "SOUTH AFRICA" => "ZAR",
    "ENGLAND" => "GBP",
    "AUSTRALIA" => "AUD",
    "BRAZIL" => "BRL"
  }

  EUR_COUNTRIES = [ "AUSTRIA", "BELGIUM", "CYPRUS", "ESTONIA", "FINLAND", "FRANCE", "GERMANY", 
    "GREECE", "IRELAND", "ITALY", "LATVIA", "LUXEMBOURG", "MALTA", "NETHERLANDS", 
    "PORTUGAL", "SLOVAKIA", "SLOVENIA", "SPAIN", "ANDORRA", "KOSOVO", "MONTENEGRO", 
    "MONACO", "SAN MARINO", "THE VATICAN CITY" ]

  EUR_CURRENCY_MAPPING = Hash[ *EUR_COUNTRIES.collect { |country| [ country, "EUR" ] }.flatten ]
  COUNTRY_MAPPING.merge!(EUR_CURRENCY_MAPPING)

  CURRENCY_UNITS = { 
    "EUR" => "\u20AC", 
    "INR" => "\u20B9", 
    "USD" => "$",
    "ZAR" => "R",
    "GBP" => "\u00A3",
    "AUD" => "\u0024",
    "BRL" => "R$"
  }
  SUPPORTED_CURRENCIES = BILLING_CURRENCIES.reject do |currency|
    CURRENCY_NOT_SUPPORTED.include? currency
  end

end