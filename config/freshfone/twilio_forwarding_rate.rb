require "rubygems"
require 'csv'
require 'yaml'
require 'json'
 
class CSVToYaml

	def initialize
		start
	end

	def find_max_digits(numarr,country)
		size = 0
		puts "SIZE :::#{country} "

count =0
		numarr.each do |num|
			size = num.strip.size > size ? num.strip.size : size
			puts "#{count}"
			count=count+1
		end
		puts "||||#{country} == #{size} |||||||||||\n"
		size
	end


	def start
		if ARGV.size != 2
		  puts 'Usage: csv_to_json input_file.csv output_file.json'
		  puts 'This script uses the first line of the csv file as the keys for the JSON properties of the objects'
		  exit(1)
		end
		countryvscode={}
		CSV.open("./Countrycodesheet2.csv",'r').map do  |entry|
			countryvscode[entry[1]] = entry.first
			puts "#{entry[1]} = #{entry.first}\n"
		end
# return
		lines = CSV.open(ARGV[0],'r').map()
		keys = lines.delete lines.first
		 
			File.open(ARGV[1], 'w') do |f|
			  data = lines.map do |values|
			    Hash[keys.zip(values)]
			  end
			  # f.puts data.to_yaml

				json_data = JSON.pretty_generate(data)

				json = JSON.parse(json_data)
				result_data = Hash.new
				yaml_data = Hash.new
				max_length = Hash.new
# return

				json.each do |tempdata|
					maxdigits = 1
					puts "??? #{tempdata['Name']}"
					countrycode = countryvscode[tempdata['Name']].strip.to_s
					countrycode = tempdata['Name'] unless countryvscode.include?(tempdata['Name'])

					num_arr = tempdata['Phone Numbers that Start With'].split(',').collect {|x| x.strip }
					num_arr.reverse!

					new_data = {countrycode=>{num_arr.join(',')=>{:outgoing=>tempdata['Rates/min'].to_f,:standard=>tempdata['Standard'].to_f,:usca_tollfree=>tempdata['US/CA Toll Free'].to_f,:uk_tollfree=>tempdata['UK Toll Free'].to_f}}}
					# outgoing=>tempdata['Rates/min'],tempdata['Standard'],tempdata['US/CA Toll Free'],tempdata['UK Toll Free']
				 	numbers = tempdata['Phone Numbers that Start With']
					# puts "#{tempdata['Name']} => #{countryvscode[tempdata['Name']]}"

				 	temp = find_max_digits(numbers.split(','),tempdata['Name'])
				 	maxdigits =  maxdigits > temp ? maxdigits : temp
				 	max_length[countrycode] = maxdigits if max_length[countrycode].nil?
				 	max_length[countrycode] = (max_length[countrycode]>maxdigits) ? max_length[countrycode] : maxdigits
								 		
					if (result_data.has_key?(countrycode))
						result_data[countrycode].merge!(new_data[countrycode]) 
					else				
						result_data.merge!(new_data)
					end
					yaml_data[countrycode] = {:max_digits=>max_length[countrycode],:numbers=>result_data[countrycode],:country=>tempdata['Name'].to_s}
				end
				yaml_data['INCOMING'] = {:standard=>0.015,:usca_tollfree=>0.04,:uk_tollfree=>0.078}
				yaml_data['VOICEMAIL'] = {:standard=>0.0125,:usca_tollfree=>0.037,:uk_tollfree=>0.075}
			 # puts "\n #{yaml_data} \n"

			# f.puts result_data.to_yaml
			f.puts yaml_data.to_yaml
		end
	end

end

CSVToYaml.new