namespace :localstack do

  desc "Create S3 buckets and SQS queues on localstack"
  task :create => :environment do
    #create S3 buckets
    Localstack::S3.create

    #create sqs queues
    Localstack::Sqs.create

    #create dynamo tables
  end
end
