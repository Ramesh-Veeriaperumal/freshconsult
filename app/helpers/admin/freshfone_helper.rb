module Admin::FreshfoneHelper
	include Carmen
	def supported_countries
		TwilioMaster.account.available_phone_numbers.list.map{|c| [c.country, c.country_code]}.sort
	end

	def toll_free_supported_countries
		[
			["Canada", "CA"],
			["United Kingdom", "GB"],
			["United States", "US"]
		]
	end

	def toll_free_prefixes
		us_canada_toll_free_numbers = ["Any", "800", "855", "866", "877", "888"]
		{
			"US" => {:numbers => us_canada_toll_free_numbers, :default => "Any"},
			"CA" => {:numbers => us_canada_toll_free_numbers, :default => "Any"},
			"GB" => {:numbers => ["800"], :default => "800"}
		}
	end

	def us_cities #Carmen gem to fetch states in a country
		Country.coded('US').subregions
	end

	def self.city_name(country_code, city_code)
		country_regions = Country.coded(country_code).subregions
		if country_regions.any?
			city = country_regions.coded(city_code)
			city ? city.name : nil	
		else
			nil
		end
	end

	def self.country_name(country_code)
		country= Country.coded(country_code)
		country ? country.name : nil
	end

	def default_state_option
		"<option value=''>All States</option>" 
	end

	def method_missing(symbol, *params)
   if (symbol.to_s =~ /^(.*)_before_type_cast$/)
     send $1
   else
     super
   end
 end

end