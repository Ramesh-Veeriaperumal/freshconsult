require "rubygems"
require 'csv'
require 'yaml'
require 'json'
 
class TwiliPhoneNumberRate

	def initialize
		start
	end

	def start
		if ARGV.size != 2
		  puts 'Usage: csv_to_json input_file.csv output_file.json'
		  puts 'This script uses the first line of the csv file as the keys for the JSON properties of the objects'
		  exit(1)
		end
		lines = CSV.open(ARGV[0],'r').map()
		keys = lines.first
		 # lines.first.reject
			File.open(ARGV[1], 'w') do |f|
			  data = lines.map do |values|
			    Hash[keys.zip(values)]
			  end

				json_data = JSON.pretty_generate(data)

				json = JSON.parse(json_data)
				result_data = Hash.new
				yaml_data = Hash.new

				json.each do |tempdata|
					maxdigits = 1
					# ISO,Country,Country Code,Price /num/month,Beta Status,Address Required,Type of number,Inbound price/min

					area = tempdata['Type of number'].gsub(" ","_").downcase
					area = 'local' if area == 'geographic'
					cost = tempdata['Price /num/month'].strip.gsub('$','').to_f
					address_required = tempdata['Address Required'] == "Yes" ? true : false
					beta = tempdata['Beta Status'] == "Yes" ? true : false
					new_data = {tempdata['ISO']=>{
						'name'=>tempdata['Country'], 
						'beta'=>beta,
						'address_required'=>address_required,area=>cost}}



					if (result_data.has_key?(tempdata['ISO']))
						result_data[tempdata['ISO']].merge!(new_data[tempdata['ISO']]) 
					else				
						result_data.merge!(new_data)
					end
					yaml_data[tempdata['ISO']] = result_data[tempdata['ISO']]
					yaml_keys = yaml_data[tempdata['ISO']].keys
					unless yaml_keys.include?('local')
							yaml_data[tempdata['ISO']]['local'] = yaml_data[tempdata['ISO']]['national'] if yaml_keys.include?('national')
					end
				end
			 puts "\n #{yaml_data} \n"

			f.puts yaml_data.to_yaml
		end
	end

end

TwiliPhoneNumberRate.new