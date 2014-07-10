class Integrations::CrmUtil


def self.fetch_crm_entity_id (ticket, current_user)

puts "fetch_entity_id - ticket #{ticket.inspect} -- "
puts "current_user #{current_user}"
puts "email  #{ticket.requester.email}" 
puts "Subject #{ticket.subject}"
puts "ticket id #{ticket.description}"

api_key = "6148e72103e5f20aa541e96f90925e76"

http_parameter = construct_params_for_http(ticket)
#http_parameter[:body] = params[:body]
res_data = make_rest_call(http_parameter)
puts "res_data #{res_data}"

end


#https://crm.zoho.com/crm/private/xml/Notes/insertRecords?authtoken=6148e72103e5f20aa541e96f90925e76&newFormat=1&scope=crmapi&xmlData=<Notes> <row no="1"> <FL val="entityId">1163424000000078001</FL> <FL val="Note Title">Zoho CRM Sample Note</FL> <FL val="Note Content">This is sample content to test Zoho CRM API</FL> </row> </Notes>

def self.construct_params_for_http(ticket)
	#postData='<?xml version="1.0" encoding="utf-8"?><Notes><row no="1"><FL val="entityId">1163424000000078001</FL><FL val="Note Title">note title</FL><FL val="Note Content">This is sample content to test Zoho CRM API</FL></row></Notes>'
    #rest_url = "https://crm.zoho.com/crm/private/xml/Notes/insertRecords?authtoken=6148e72103e5f20aa541e96f90925e76&scope=crmapi"
    subject = ticket.subject
    ticket_description = ticket.description

    rest_url= "crm/private/xml/Notes/insertRecords?authtoken=6148e72103e5f20aa541e96f90925e76&newFormat=1&scope=crmapi&xmlData=<Notes> <row no='1'> <FL val='entityId'>1163424000000078001</FL> <FL val='Note Title'>#{subject}</FL> <FL val='Note Content'>#{ticket_description}</FL> </row> </Notes>"

puts "rest_url #{rest_url}"
    req_obj = { 
		:content_type => "application/xml",
		:method => "post",
		:domain => "https://crm.zoho.com",
      	:rest_url => rest_url
   
    }
  end

  def self.make_rest_call(params,request = nil)
  	@http_request_proxy = HttpRequestProxy.new
    res_data = @http_request_proxy.fetch(params,request)
  end

end
