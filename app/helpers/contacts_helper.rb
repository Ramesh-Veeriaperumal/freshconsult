module ContactsHelper

	def contact_tabs(type)
		tabs = [['contacts', t('contacts.title')],
				['customers', t('company.title')]]
		ul tabs.map{ |t| 
		              link_to t[1], "/#{t[0]}", :id => "#{t[0]}Tab", :class => "#{t[2]}"
		            }, { :class => "tabs nav-tabs", :id => "contacts-tab" }, type.eql?('user') ? 0 : 1
	end

end
