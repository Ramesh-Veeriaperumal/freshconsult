class Monitoring::RecordMetrics
  
  THRESHOLD_IN_SECS = 180
  JOB_WAITING_THRESHOLD_IN_SECS = 1800 

  def self.performance_data(metrics_data)
  	if metrics_data[:time_spent] > THRESHOLD_IN_SECS || metrics_data[:job_waiting_time] > JOB_WAITING_THRESHOLD_IN_SECS
  		metrics_data[:time_spent] = metrics_data[:time_spent]/1.minutes
      metrics_data[:job_waiting_time] = metrics_data[:job_waiting_time]/1.minutes
  		Resque.enqueue(Monitoring::SplunkStorm, metrics_data) 
  	end
  end
  
  def self.register(metrics_data)
  	metrics_data.merge({:timestamp => Time.zone.now})
  	Resque.enqueue(Monitoring::SplunkStorm, metrics_data)
  end


end