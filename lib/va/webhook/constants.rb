module Va::Webhook::Constants

	XML = 1
	#spent 2 hours debugging why JSON.parse dint work, found here that we have named it as constant :)
	JAVASCRIPT_OBJECT_NOTATION = J_S_O_N = 2
	URL_ENCODED = 3

	CONTENT_TYPE = { 	
										XML =>'text/xml', 
										J_S_O_N => 'application/json' ,
										URL_ENCODED => 'application/x-www-form-urlencoded'
									}

	REQUEST_TYPE = { 	
										1 => 'get', 
										2 => 'post', 
										3 => 'put', 
										4 => 'patch', 
										5 => 'delete'
									}

	SIMPLE_WEBHOOK = 1
	ADVANCED_WEBHOOK = 2 

end