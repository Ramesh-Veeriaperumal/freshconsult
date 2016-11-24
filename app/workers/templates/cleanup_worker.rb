class Templates::CleanupWorker < BaseWorker

  sidekiq_options :queue => :templates_cleanup, :retry => 0, :backtrace => true,
                  :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    acc = Account.current
    templates = acc.send("#{args[:assn_item_type]}_templates").where(id: args[:templates_ids])
    templates.each do |templ|
      templ.reset_tmpl_assoc = true
      if args[:assn_item_type] == "parent"
        templ.update_attributes(association_type:
          Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general])
      elsif args[:assn_item_type] == "child"
        templ.destroy
      end
    end
  rescue Exception => e
    puts e.inspect, args.inspect
    NewRelic::Agent.notice_error(e, {:description => "Error in templ cleanup ::
      #{args[:assn_item_type]} :: #{args[:templates_ids]} :: #{acc.id}"})
    raise e
  end
end
