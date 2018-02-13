module Localstack
  class Sqs    
    class << self
      def create
        sqs_config = YAML::load_file(File.join(Rails.root,"config","sqs.yml"))[Rails.env]
  
        sqs_config.each do |queue, name|
          puts "Creating SQS Queue : #{queue} - #{name}"

          $sqs_v2_client.create_queue({
            queue_name: name, # required
            attributes: {
              "All" => "String",
          }})
        end
      end

      def cleanup
      end
    end    
  end  
end

