module CRM::TotangoOptions
	MODULES_AND_ACTIONS = {
		:account_activation  => { :module => "Account", :action => "Activation Done" },

		:helpdesk_rebranding => { :module => "Helpdesk Rebranding", :action=> "Rebranding Done"},

		:agents  			 => { :module => "Agents", :action => "New Agent Added"},

		:arcade 			 => { :module => "Arcade", :action => "Points Updated" },

		:quests 			 => { :module => "Quests", :action => "New Quest Created" },

		:email_config 		 => { :module => "Email Settings", :action => "Support Email Edited"},

		:multiple_products   => { :module => "Multiple Products", :action => "New Product Added"},

		:twitter 			 => { :module => "Twitter", :action => "Twitter Account Added" },
		
		:facebook 			 => { :module => "Facebook", :action => "Facebook Page Added" }
	}
end