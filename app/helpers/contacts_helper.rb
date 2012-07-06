module ContactsHelper

	def contact_tabs(type)
		tabs = [['customers', t('company.title')],
		        ['contacts', t('contacts.title')]]
		ul tabs.map{ |t| 
		              link_to t[1], "/#{t[0]}", :id => "#{t[0]}Tab"
		            }, { :class => "tabs right-tabs", "data-tabs" => "tabs" }, type.eql?('user')? 1 : 0
	end

end
