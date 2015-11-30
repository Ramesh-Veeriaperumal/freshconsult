module RabbitMq::Helper

  ## TODO Must send only one push for all the subscribers(reports, search, activities)
  # Currently only reports is handled.
  # Need to handle it in a generic way for all the subscribers
  def send_updates_to_rmq(items, klass_name)
    items.each do |item|
      item.reload ## Here reloading to get the current state of the object. TODO check if it will trigger any performace impact. Must reorg
      key = RabbitMq::Constants.const_get("RMQ_REPORTS_#{klass_name.demodulize.tableize.singularize.upcase}_KEY")
      item.manual_publish_to_rmq("update", key, {:manual_publish => true})
    end
  end
end
