Authority::Authorization::PrivilegeList.build do
  manage_tickets do
    resource :"ember/bootstrap"
    resource :"ember/ticket", only: [:index, :spam, :bulk_spam, :unspam, :bulk_unspam, 
                                      :execute_scenario, :bulk_execute_scenario]
    resource :"ember/scenario_automation", only: [:index]
    resource :"ember/ticket", only: [:index, :spam]
  end

  delete_contact do
    resource :"ember/contact", only: [:bulk_delete, :destroy, :bulk_restore, :restore]
  end

  view_contacts do
    resource :"ember/contact", only: [:index, :show]
  end

  manage_contacts do
    resource :"ember/contact", only: [:create, :update]
  end

  manage_users do
    resource :"ember/contact", only: [:make_agent]
  end

	delete_ticket do
		resource :"ember/ticket", only: [:destroy, :bulk_delete, :restore, :bulk_restore]
	end
end
