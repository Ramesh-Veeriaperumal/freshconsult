module Redis::SlowlogParser
	require 'csv'

  class << self
	
	  def parse(slowlog)
	  	# Slowlog format is an array of arrays, in the sequence of unique identifier, timestamp, 
	  	# 	execution time in microseconds, complexity info, full command(array).
	  	# [ [71515, 1512283859, 1234, "", ["lrange", "RR_CAPPING_TICKETS_QUEUE:12345:123", "0", "-1"]],
	  	#  	[71514, 1511959782, 1234, "Complexity info: N:26148", ["smembers", "SPAM_EMAIL_ACCOUNTS"]],
	  	#   ["lrange", "RR_CAPPING_TICKETS_QUEUE:123:1234", "0", "-1"]] ]

	  	csv_data = []
	  	slowlog.each do |entry|	
	  		# Extracting everything except the unique identifer.
		    csv_data << "#{Time.at entry[1]}, #{entry[2] / 1000.0}ms, #{entry[3]}, #{entry[4].join(" ").squeeze(" ")}"
	  	end
	    return csv_data.to_csv
	  end

	end
end