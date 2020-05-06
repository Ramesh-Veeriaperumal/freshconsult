module Publish
  def manual_publish(rmq_publish_args, central_publish_args, delayed = false)
    # generate and send common uuid to rabbitmq and kafka
    uuid = RabbitMq::Utils.generate_uuid
    # publish to rabbitmq
    if rmq_publish_args.present?
      delayed ? delayed_manual_publish_to_rmq(uuid, *rmq_publish_args) : manual_publish_to_rmq(uuid, *rmq_publish_args)
    end
    # publish to Central
    if self.respond_to?(:manual_publish_to_central) && central_publish_args.present?
      manual_publish_to_central(uuid, *central_publish_args, delayed)
    end
  end
end