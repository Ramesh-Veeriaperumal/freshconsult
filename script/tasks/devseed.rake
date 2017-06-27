namespace :devseed do
    
  desc "Create the necessary SQS Queues in Local environment"
  task :sqs => :environment do 
    next if !Rails.env.development? && !Rails.env.test?
    # Just to abort for non dev environments
    puts ""
    puts "Creating the necessary queues"
    sqs_config = YAML::load(ERB.new(File.read("#{Rails.root}/config/sqs.yml")).result)
    queue_list = (sqs_config[Rails.env] || sqs_config).symbolize_keys
    
    puts queue_list.inspect
    queue_list.values.each do |q|
      $sqs_v2_client.create_queue(queue_name: q)
      puts "Created #{q}"
    end
    
    # Additional queues
    ["es_etl_migration_queue_#{Rails.env}"].each do |q|
      $sqs_v2_client.create_queue(queue_name: q)
      puts "Created #{q}"
    end
  end
  

end