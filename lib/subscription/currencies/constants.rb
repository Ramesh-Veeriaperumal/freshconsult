module Subscription::Currencies::Constants

  BILLING_CURRENCIES = [ "EUR", "INR", "USD", "ZAR", "BRL" ]
  DEFAULT_CURRENCY = "USD"

  COUNTRY_MAPPING = 	{
    "INDIA" => "INR",
    "BRAZIL" => "BRL",
    "SOUTH AFRICA" => "ZAR"
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
    "BRL" => "R$"
  }

end