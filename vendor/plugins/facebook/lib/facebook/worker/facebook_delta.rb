#This Rescue is used for calculating the delta once the access token expires and when reauthrized again
class Facebook::Worker::FacebookDelta
  extend Resque::AroundPerform

  @queue = "facebook_realtime_delta_worker"

  def self.perform(args)
    account = Account.current
    add_feeds_to_sqs(args[:page_id],args[:discard_feed])
  end

  #sort and push to sqs need to figure it out
  def self.add_feeds_to_sqs(page_id, discard_feed)
    begin
      dynamo_db_facebook = AwsWrapper::DynamoDb.new(SQS[:facebook_realtime_queue])
      query_options = {
        :select => "ALL_ATTRIBUTES",
        :consistent_read => true,
        :key_conditions => {
          "page_id" => {
            :comparison_operator => "EQ",
            :attribute_value_list => [
              {'n' => "#{page_id}"}
            ]
          }
        }
      }
      response = {}
      while true
        response = dynamo_db_facebook.query(query_options)
        response[:member].each do |data|
          $sqs_facebook.send_message(data["feed"][:s]) unless discard_feed
          dynamo_db_facebook.query_delete_facebook(data["page_id"][:n],data["timestamp"][:n])
        end
        break unless response[:last_evaluated_key]
        query_options = query_options.merge({ :exclusive_start_key => response[:last_evaluated_key]})
      end
    rescue Exception => e
      SocialErrorsMailer.deliver_facebook_exception(e) unless Rails.env.test?
      Rails.logger.error "cannot read data from dynamo db"
      NewRelic::Agent.notice_error(e,{:description => "cannot read data from dynamo db"})
    end
  end
  
end