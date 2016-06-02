module RabbitMq::SqsMessage

  def skeleton_message(model, action, uuid, account_id)
    Hash.new.tap do |sqs_params|
      sqs_params["object"]                =  model
      sqs_params["action"]                =  action
      sqs_params["action_epoch"]          =  Time.zone.now.to_f
      sqs_params["uuid"]                  =  uuid
      sqs_params["account_id"]            =  account_id
      sqs_params["#{model}_properties"]   =  {}
      sqs_params["subscriber_properties"] =  {}
    end
  end
  
  module_function :skeleton_message
end