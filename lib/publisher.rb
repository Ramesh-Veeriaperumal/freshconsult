module Publisher
  def publish_to_central(options = {})
    account_association = options[:rel_table_args][:account_association]

    Account.current.send(account_association).where("#{options[:rel_table]}.id IN (?)", options[:ids]).find_each do |associated_object|
      if options[:rel_table_args][:destroy]
        presenter_method = options[:rel_table_args][:presenter_method]
        associated_object.safe_send(presenter_method) if presenter_method && associated_object.respond_to?(presenter_method, true)
      end

      publish_args_method = "#{options[:rel_table]}_publish_args"
      publish_args = respond_to?(publish_args_method, true) ? safe_send(publish_args_method, associated_object, options) : [nil, nil]
      associated_object.manual_publish(*publish_args) if associated_object.respond_to?(:manual_publish, true)
    end
  end
end
