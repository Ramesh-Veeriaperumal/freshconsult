class Monitoring::RecordMetrics
  
  THRESHOLD_IN_SECS = 180 

  def self.performance_data(metrics_data)
  	if metrics_data[:time_spent] > THRESHOLD_IN_SECS
  		metrics_data[:time_spent] = metrics_data[:time_spent]/1.minutes
  		Resque.enqueue(Monitoring::SplunkStorm, metrics_data) 
  	end
  end
  
  def self.register(metrics_data)
  	metrics_data.merge({:timestamp => Time.zone.now})
  	Resque.enqueue(Monitoring::SplunkStorm, metrics_data)
  end


end