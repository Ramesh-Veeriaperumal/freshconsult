module Admin::FreshfoneHelper
	include Carmen
	def supported_countries(countries=[])
		numbers = reject_beta_numbers
		numbers = filter_trial_local(numbers) if freshfone_trial? || trial_search?
		numbers.each do |number|
			(countries << [ number[1]["name"], number[0] ])
		end
		(countries || []).sort
	end

	def toll_free_supported_countries
		[
			["Canada", "CA"],
			["United Kingdom", "GB"],
			["United States", "US"],
			["Australia", "AU"]
		]
	end

	def toll_free_prefixes
		us_canada_toll_free_numbers = ["Any", "800", "855", "866", "877", "888"]
		result = {
				"US" => { :numbers => us_canada_toll_free_numbers, :default => "Any" },
				"CA" => { :numbers => us_canada_toll_free_numbers, :default => "Any" },
				"GB" => { :numbers => ["800"], :default => "800"} }
		(freshfone_trial? || trial_search?) ? filter_trial_toll_free(result,toll_free_countries) : result
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

	def reject_beta_numbers
		Freshfone::Cost::NUMBERS.reject { |k, v| v['beta'] }
	end

	def toll_free_countries
		reject_beta_numbers.select{ |k,v| v['toll_free'].present? }
	end

	def number_credit
		@number_credit ||= Freshfone::Subscription.fetch_number_credit(current_account)
	end

	def filter_trial_local(country_list)
		country_list.select { |_k, v| filter_trial_credit(v) }
	end

	def filter_trial_toll_free(selections, toll_free_countries)
		allowed_countries = toll_free_countries.select { |_k, v| v['toll_free'] <= number_credit.to_f }.keys
		selections.select { |k, _v| allowed_countries.include?(k) }
	end

	def can_allow_toll_free?
		return true unless trial_search? # if it is not trial dont do anything
		min_country = Freshfone::Cost::NUMBERS.reject { |_k, v| v['toll_free'].blank? }.min_by { |k, v| v['toll_free'] } # for fetching the min country details
		return if min_country.blank?
		(min_country.last['toll_free'].to_f <= number_credit.to_f)
	end

	def trial_search?
		@freshfone_subscription.present? && @freshfone_subscription == 'trial'
	end

	def buy_text_helper
		return t('freshfone.admin.trial.numbers.search.buy_button') if trial_search?
		t('freshfone.admin.numbers.buy_button_text')
	end

	def filter_trial_credit(number_info)
		(number_info.key?('local') && number_info['local'] <= number_credit.to_f) ||
			(number_info.key?('mobile') && number_info['mobile'] <= number_credit.to_f)
	end

 # TODO-RAILS3 need to check why they have this...
 # def method_missing(symbol, *params)
 #   if (symbol.to_s =~ /^(.*)_before_type_cast$/)
 #     send $1
 #   else
 #     super
 #   end
 # end

end