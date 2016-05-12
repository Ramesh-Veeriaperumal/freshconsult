statsd_config = YAML.load_file(File.join(Rails.root, 'config', 'statsd.yml'))[Rails.env]
$statsd = Statsd::Statsd.new(statsd_config["host"], statsd_config["port"])

def statsd_increment(shard,counter_name)
	$statsd.increment("#{counter_name}._shard=#{shard}")
end

def statsd_timing(shard,timer_name,time)
	$statsd.timing("#{timer_name}._shard=#{shard}",time)
end

TRACKED_MODELS = ["Helpdesk::Ticket","Helpdesk::Note","Solution::Article","User","Account"] 

TRACKED_CONTROLLERS = {"Support::SignupsController" => :create,"Support::Solutions::ArticlesController" => :thumbs_up ,"Solution::ArticlesController" => :thumbs_up,"Support::Multilingual::Solutions::ArticlesController" => :thumbs_up,"Mobihelp::Multilingual::ArticlesController" => :thumbs_up,"Mobihelp::ArticlesController" => :thumbs_up ,"EmailController" => :create}

TRACKED_RESPONSE_TIME = {"Helpdesk::TicketsController" => [:show,:index,:create] , "Support::TicketsController" => [:show,:index,:create] }

TRACKED_TICKET_SOURCE = {2 =>"portal",5=> "twitter",6 =>"facebook",8=>"mobihelp",9=>"feedback_widget",10=>"outbound_email"}
