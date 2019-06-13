class SendDomainChangedMail < BaseWorker

  sidekiq_options :queue => :send_domain_changed_mail, :retry => 0, :failures => :exhausted

  def perform(args)
  	args.symbolize_keys!
    Account.current.technicians.each do |agent|
      CustomizeDomainMailer.domain_changed({to_email: agent.email, name: agent.first_name, url: Account.current.full_url, is_agent: !agent.privilege?(:admin_tasks), account_name: args[:account_name]})
      agent.enqueue_activation_email
    end
  end
end