module CRM::TotangoOptions
	MODULES_AND_ACTIONS = {
		:account_activation  => { :module => "Basic", :action => "Email Verified" },

		:helpdesk_rebranding => { :module => "Portal Customization", :action=> "Portal Rebranded"},

		:agents  			 => { :module => "Helpdesk Settings", :action => "Agents Added"},

		:arcade 			 => { :module => "Advanced", :action => "Arcade Updated" },

		:quests 			 => { :module => "Advanced", :action => "Quest Created" },

		:email_config 		 => { :module => "Helpdesk Settings", :action => "Email Setup"},

		:multiple_products   => { :module => "Advanced", :action => "Product Added"},

		:twitter 			 => { :module => "Social", :action => "Twitter Account Added" },
		
		:facebook 			 => { :module => "Social", :action => "Facebook Account Added" }
	}
end