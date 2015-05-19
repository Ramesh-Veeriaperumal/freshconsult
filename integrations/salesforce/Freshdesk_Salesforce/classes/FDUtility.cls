public with sharing class FDUtility {
    public static TicketComment ticket_comment{get; set;}
    public static TicketComment[] ticket_notes{get; set;}
    public static string ticket_response{get; set;}
    public static CustomFields[] customFields{get; set;}
    public static List<Ticket> tickets{get; set;}
    public static string url{get; set;}
    public static string apikey{get; set;}
    public static string pwd{get; set;}
    public static string assume_pwd{get; set;}
    public static boolean isApexTest = false;
    public static boolean isApexTest1 = false;
    public static Attachments[] att{get; set;}
    
    
    static {
        //Organization specific authorization
        RemoteAuth__c auth = RemoteAuth__c.getOrgDefaults();
        apikey = auth.fd_username__c;
        
        pwd = 'x';
        url = auth.fd_url__c;
        
        String userId = UserInfo.getUserId();
        User currentUser = [Select Email From User where Id = : userId limit 1];
        assume_pwd = 'assume='+currentUser.Email;
        
    }
    
    
    //Get All Tickets
    public static Ticket[] getAllTickets(string param, string paramType, integer page){
        //System.debug('FDUtility getAllTickets' + param + ' --- paramType = ' + paramType);
        //System.debug('FDUtility getAllTickets'+' '+'account'+param);
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        if(param == null || param.equals(''))
        { 
            return new Ticket[0]; //added by roshini
            
        }
        string resource = (paramType == 'email') ? ('/helpdesk/tickets.xml?filter_name=all_tickets&email=' + param) : ('/helpdesk/tickets.xml?filter_name=all_tickets&company_name=' + EncodingUtil.urlEncode(param, 'UTF-8'));
        req.setEndpoint(url + resource + '&wf_per_page=5&page=' + page);
        Blob headerValue = Blob.valueOf(apikey + ':' + pwd);
        String authorizationHeader = 'Basic ' +
        EncodingUtil.base64Encode(headerValue);
        req.setHeader('Authorization', authorizationHeader);
        Http http = new Http();
        if(!(Test.isRunningTest())){
            HTTPResponse res = http.send(req);
            if((res.getHeader('Content-Type') != null && res.getHeader('Content-Type').contains('text/html')) || (res.getStatusCode() == 503) || (res.getStatusCode() == -1)){
                return new Ticket[0]; //send empty array instead of null - Hrishikesh
            }   
            ticket_response = res.getBody();
        }
        else{
            ticket_response = '<?xml version="1.0" encoding="UTF-8"?><helpdesk-tickets type="array"><helpdesk-ticket><display-id type="integer">148</display-id><subject>gh</subject><updated-at type="datetime">2013-07-30T15:14:01+05:30</updated-at><status-name>Open</status-name><priority-name>Low</priority-name></helpdesk-ticket><helpdesk-ticket><display-id type="integer">148</display-id><subject>gh</subject><updated-at type="datetime">2013-07-30T15:14:01+05:30</updated-at><status-name>Open</status-name><priority-name>Low</priority-name></helpdesk-ticket><helpdesk-ticket><display-id type="integer">148</display-id><subject>gh</subject><updated-at type="datetime">2013-07-30T15:14:01+05:30</updated-at><status-name>Open</status-name><priority-name>Low</priority-name></helpdesk-ticket><helpdesk-ticket><display-id type="integer">148</display-id><subject>gh</subject><updated-at type="datetime">2013-07-30T15:14:01+05:30</updated-at><status-name>Open</status-name><priority-name>Low</priority-name></helpdesk-ticket><helpdesk-ticket><display-id type="integer">148</display-id><subject>gh</subject><updated-at type="datetime">2013-07-30T15:14:01+05:30</updated-at><status-name>Open</status-name><priority-name>Low</priority-name></helpdesk-ticket></helpdesk-tickets>';
        }
        JSONParser parser = JSON.createParser(ticket_response);
        tickets = new List<Ticket>(); //Update with ticket count from json size
        string subject, status, updatedAt, ticketId, priority;
        DOM.Document doc = new DOM.Document();     
        doc.load(ticket_response);
        DOM.XMLNode root = doc.getRootElement();
        for (Dom.XMLNode helpdesk_tickets: root.getChildElements()) {
            for (Dom.XMLNode ticket: helpdesk_tickets.getChildElements()) {
                if(ticket.getName() == 'subject'){
                    subject = ticket.getText();
                }
                else if(ticket.getName() == 'status-name'){
                    status = ticket.getText();
                }
                else if(ticket.getName() == 'updated-at'){
                    updatedAt = formatUTCDate(ticket.getText());
                }
                else if(ticket.getName() == 'display-id'){
                    ticketId = ticket.getText();
                }
                else if(ticket.getName() == 'priority-name'){
                    priority = ticket.getText();
                }
            }
            if(ticketId != null)
                tickets.add(new Ticket(ticketId, subject, status, priority, updatedAt));
        } 
        return tickets;
    }
    
    //Push Contacts Details
    
    
    
    
    //Fetch CSAT Details
    
    public static String fetchCSATForTicket(string ticketId) {
        //System.debug('fetch CSAT for id ' + ticketId);
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(url + '/helpdesk/tickets/' + ticketId + '/surveys.json');
        Blob headerValue = Blob.valueOf(apikey + ':' + pwd);
        String authorizationHeader = 'Basic ' +
        EncodingUtil.base64Encode(headerValue);
        req.setHeader('Authorization', authorizationHeader);
        Http http = new Http();
        String ticket_csat = '';
        String rating = '';
        String surveyresponse=null;
         if(!(Test.isRunningTest())){
            //System.debug('inside is not Apex Tet code');
            HTTPResponse res = http.send(req);
            if(res.getHeader('Content-Type') == 'text/html; charset=utf-8'){
                return null;
            }
            
            surveyresponse=res.getBody();
            //System.debug('ticket csat response ' + res.getBody());
          }  
         else {
            surveyresponse='[{ "survey_result" : { "agent_id" : null,"created_at" : "2013-08-24T12:58:48+05:30","customer_id" : 4722354,"group_id" : null,"id" : 163649,"rating" : 1,"response_note_id" : null,"survey_id" : 16609,"surveyable_id" : 13714431,"surveyable_type" : "Helpdesk::Ticket","updated_at" : "2013-08-24T12:58:48+05:30" } }]';
            //System.debug('inside else Apex code');
         }
            if(surveyresponse != null) {
                //System.debug('Inside not Null');
            JSONParser parser = JSON.createParser(surveyresponse);
             while (parser.nextToken() != null) {
                 if (parser.getCurrentToken() == JSONToken.START_OBJECT)  
                    { 
                        while (parser.nextToken() !=  JSONToken.END_OBJECT)  
                        {  
                            //System.debug('params text ' + parser.getText());
                            if((parser.getText() == 'rating'))
                            {
                                //System.debug('rating ' );
                                parser.nextToken() ;
                                rating = parser.getText();
                                //System.debug('rating value ' + rating);
                                break;
                            }//if
                        }//while
                     } //if
             }//while
            }
         
         
         System.debug('Rating Val == ' + rating);
         
         if(rating == '1'){
            ticket_csat = 'happy-smily-small.png';
         }else if (rating =='2') {
            ticket_csat = 'neutral-smily-small.png';
         }else if (rating == '3'){
            ticket_csat = 'unhappy-smily-small.png';
         }
         //System.debug('ticket_csat return val ' + ticket_csat);
        return ticket_csat;
        
    }
    
    //Fetch Ticket Details
    public static Ticket fetchTickets(string ticketId){
        //System.debug('FDUtility Cls - fetchTickets - id = ' + ticketId + 'isApexTest' + isApexTest);
        
     HttpRequest req = new HttpRequest();
     req.setMethod('GET');
     req.setEndpoint(url + '/helpdesk/tickets/' + ticketId + '.json');
     Blob headerValue = Blob.valueOf(apikey + ':' + pwd);
     String authorizationHeader = 'Basic ' +
     EncodingUtil.base64Encode(headerValue);
     req.setHeader('Authorization', authorizationHeader);
     Http http = new Http();
     List<CustomFields> custom = null;
     System.debug('Check for Test environment'+' '+Test.isRunningTest());
     if(!(Test.isRunningTest())){
            HTTPResponse res = http.send(req);
            if(res.getHeader('Content-Type') == 'text/html; charset=utf-8')
                return null;
            ticket_response = res.getBody();
            //System.debug('ticket response ' + ticket_response);
            custom = populateCustomFields();
            //System.debug('custom = ' + custom);
        }
        else{
        ticket_response = '{"helpdesk_ticket":{"urgent":false,"updated_at":"2012-06-25T18:52:56+05:30","product_72":null,"owner_id":null,"lev2_72":null,"cc_email":{"fwd_emails":[],"cc_emails":[]},"display_id":819,"created_at":"2012-06-08T18:45:52+05:30","status_name":"Open","id":9006,"delta":true,"cat1_72":null,"ajkdlasdlkjasdl_72":null,"requester_id":11632,"lev3_72":null,"fr_escalated":false,"deleted":false,"aklsdjasdaksdjalsdj_72":null,"attachments":[{"content_content_type":"application/pdf","content_file_name":"ruby_on_rails_tutorial_2nd_edition-preview.pdf","id":1020460481,"attachment_url":"https://s3.amazonaws.com"}],"to_email":"support@test@test.com","subject":"Testing sales force integration","isescalated":false,"frDueBy":"2012-06-09T18:45:52+05:30","group_id":269,"due_by":"2012-06-11T18:45:52+05:30","adsaksdljasdlkad_72":null,"source_name":"Email","spam":false,"email_config_id":85,"description":"Sales force integration test","custom_field":{"product_72":null,"agent":"roshini","other2_123875":"subcategory1","other3_123875":"item1","cat1_72":null,"ajkdlasdlkjasdl_72":null,"lev3_72":null,"aklsdjasdaksdjalsdj_72":null,"adsaksdljasdlkad_72":null},"ticket_type":"Question","responder_id":5778,"description_html":"<div><div>Sales force integration test</div></div>","notes":[{"updated_at":"2012-06-25T18:52:56+05:30","body_html":"","notable_type":"Helpdesk::Ticket","created_at":"2012-06-25T18:52:56+05:30","private":false,"id":4423,"incoming":false,"deleted":false,"user_id":5778,"notable_id":9006,"body":"Testerest    On June 25 @ 04:22 PM elderscrolls&lt;support@test@test.com&gt; wrote: Yo    -- Note added by test@test.com from Salesforce   ","source":0}],"responder_name":"Sathappan","priority_name":"Low","status":2,"source":1,"trained":false,"priority":1}}';            custom=new List<CustomFields>();
        custom = populateCustomFields();
        }
        //System.debug('response - ticket = ' + ticket_response);
        
     JSONParser parser = JSON.createParser(ticket_response);
     Ticket ticket = new Ticket();
     while (parser.nextToken() != null) {
         if (parser.getCurrentToken() == JSONToken.START_OBJECT)  
            {     
                while (parser.nextToken() !=  JSONToken.END_OBJECT)  
                {  
                    //System.debug('params text ' + parser.getText());
                     
                    if((parser.getText() == 'cc_email')){
                        if (parser.nextToken() == JSONToken.START_OBJECT)  
                        {
                            while (parser.nextToken() !=  JSONToken.END_OBJECT){
                                //parser.nextToken();
                                if(parser.getCurrentToken() == JSONToken.START_ARRAY){
                                    while(parser.nextToken() != JSONToken.END_ARRAY){
                                        ticket.cc_email = parser.getText();
                                    }
                                }
                                        
                            }
                        }
                        
                    }
    // Ticket attachments                
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) && (parser.getText() == 'attachments')){
                        att=new List<Attachments>();
                      if(parser.nextToken() == JSONToken.START_ARRAY){
                        while(parser.nextToken() != JSONToken.END_ARRAY){
                             if(parser.getCurrentToken() == JSONToken.START_OBJECT)
                                        {
                                            Attachments atts = new Attachments();
                                            while(parser.nextToken() != JSONToken.END_OBJECT)
                                            {
                                                if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'attachment_url'))  
                                                {
                                                    parser.nextToken();
                                                    atts.attachment_url = parser.getText(); 
                                                }
                                                if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'id'))  
                                                {
                                                    parser.nextToken();
                                                    atts.attachment_id = parser.getText(); 
                                                }
                                                if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'content_file_name'))  
                                                {
                                                    parser.nextToken();
                                                    atts.content_file_name = parser.getText(); 
                                                }
                                                if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'content_content_type'))  
                                                {
                                                    parser.nextToken();
                                                    atts.content_file_type = parser.getText(); 
                                                }   
                                            }
                                            
                                            att.add(atts);
                                            
                                        }
                        }
                        ticket.attachment_list=att;
                      }
                    }
                    
                    if((parser.getText() == 'params')){
                      if(parser.nextToken() == JSONToken.START_OBJECT){
                        while(parser.nextToken() != JSONToken.END_OBJECT){
                          parser.nextToken();
                        }
                      }
                    }
                    
                    
                    
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'subject'))  
                    {  
                        parser.nextToken() ;
                        //boolean isHtmlSecure  = isHTMLDataVulnerable(parser.getText());
                        ticket.subject = parser.getText();
                    }
                    
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'to_email'))  
                    {  
                        parser.nextToken() ;      
                        ticket.to_email = parser.getText();
                    }
                    
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'display_id'))  
                    {  
                        parser.nextToken() ;      
                        ticket.ticketId = parser.getText();  
                    }
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'description_html'))  
                    {  
                        parser.nextToken() ;     
                        //boolean isHtmlSecure  = isHTMLDataVulnerable(parser.getText());
                        ticket.description_html = parser.getText();  
                    }
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'description'))  
                    {  
                        parser.nextToken() ;      
                        ticket.description = parser.getText();  
                    }
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'status_name'))  
                    {  
                        parser.nextToken() ;      
                        ticket.status = parser.getText();  
                    }
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'group_id'))  
                    {
                        parser.nextToken();
                        ticket.groupId = parser.getText(); 
                    }
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'responder_id'))  
                    {
                        parser.nextToken();
                        ticket.responderId = parser.getText(); 
                    }       
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'status')){
                        parser.nextToken();
                        ticket.status_id = parser.getText();
                    }
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'priority_name'))  
                    {  
                        parser.nextToken() ;      
                        ticket.priority = parser.getText();  
                    }
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'ticket_type'))  
                    {  
                        parser.nextToken() ;      
                        ticket.ticketType = parser.getText();  
                    }
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'source'))  
                    {  
                        parser.nextToken() ;      
                        ticket.source = parser.getText();  
                    }
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'requester_id'))  
                    {  
                        parser.nextToken() ;      
                        ticket.requester = parser.getText(); 
                    }
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'created_at'))  
                    {  
                        parser.nextToken() ;      
                        ticket.createdAt = formatUTCDate(parser.getText());  
                    }
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'updated_at'))  
                    {  
                        parser.nextToken() ;      
                        ticket.updatedAt = formatUTCDate(parser.getText());  
                    }
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'due_by'))  
                    {  
                        parser.nextToken() ;      
                        ticket.dueDate = formatUTCDate(parser.getText());  
                    }
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'responder_name'))  
                    {  
                        parser.nextToken() ;      
                        ticket.responderName = parser.getText();  
                    }
                    
                    customFields = new List<CustomFields>();
                    integer j=0;
                    string field_name, field_label, field_type, field_value;
                    List<CustomFields> nestFields=null;
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'custom_field')){
                        
                          
                        
                          if (parser.nextToken() == JSONToken.START_OBJECT)  
                          {     
                           while (parser.nextToken() !=  JSONToken.END_OBJECT)  
                              {     
                                   //customFields[j] = new CustomFields();                                 
                                   if(parser.getCurrentToken() == JSONToken.FIELD_NAME){
                                        if(!isApexTest || Test.isRunningTest()){
                                            for(integer k=0; k< custom.size(); k++){
                                                if(custom.get(k) != null){
                                                    if(custom.get(k).field_name == parser.getText()){
                                                        if(custom.get(k).field_type != null){
                                                            if(custom.get(k).field_type.startsWith('custom') || custom.get(k).field_type.startsWith('default') || custom.get(k).field_type.startsWith('nested')){
                                                                field_name = custom.get(k).field_name;
                                                                field_label = custom.get(k).field_label;
                                                                field_type = custom.get(k).field_type;
                                                                //nested_fields parser
                                                                if(field_type.startsWith('nested')){
                                                                JSONParser nestedFieldsparser = JSON.createParser(ticket_response);
                                                                while (nestedFieldsparser.nextToken() != null) {
                                                                            if((nestedFieldsparser.getCurrentToken() == JSONToken.FIELD_NAME) &&(nestedFieldsparser.getText() == 'custom_field')){
                                                                                 if (nestedFieldsparser.nextToken() == JSONToken.START_OBJECT)  {
                                                                                     while (nestedFieldsparser.nextToken() !=  JSONToken.END_OBJECT){
                                                                                        if(nestedFieldsparser.getCurrentToken() == JSONToken.FIELD_NAME){
                                                                                            for(integer l=0;l< custom.get(k).nestedFields.size(); l++){
                                                                                                if(custom.get(k).nestedFields.get(l).field_name == nestedFieldsparser.getText()){
                                                                                                    nestedFieldsparser.nextToken();
                                                                                                    if(nestedFieldsparser.getText() == 'null'){
                                                                                                    custom.get(k).nestedFields.get(l).field_value='N/A';
                                                                                                    }
                                                                                                    else{
                                                                                                    custom.get(k).nestedFields.get(l).field_value=nestedFieldsparser.getText(); 
                                                                                                    }
                                                                                                    
                                                                                                }
                                                                                            }
                                                                                        }
                                                                                     }
                                                                                 }
                                                                            }
                                                                         
                                                                     }
                                                                     nestFields=custom.get(k).nestedFields;
                                                                }
                                                                
                                                                parser.nextToken();
                                                                field_value = parser.getText();
                                                                if(field_value == 'null'){
                                                                    field_value = 'N/A';
                                                                }   
                                                            }   
                                                        }
                                                        
                                                        //customFields[j].field_name = parser.getText();
                                                                
                                                    }
                                                                                                    
                                                }
                                            }                                               
                                    }
                                
                                        
                                   }
                              customFields.add(new CustomFields(field_label, field_name, field_type, null, null, field_value,nestFields));     
                              j++;
                              }  
                         }
                         ticket.custom_fields = customFields;
                              
                    }
                    
                     if((parser.getText() == 'notes')){
                      if(parser.nextToken() == JSONToken.START_ARRAY){
                        while(parser.nextToken() != JSONToken.END_ARRAY){
                          if(parser.getCurrentToken() == JSONToken.START_OBJECT){
                            while(parser.nextToken() != JSONToken.END_OBJECT){  
                                parser.nextToken();  
                            }
                          }
                        }
                      }
                    }
                    
                    
                }
            }  
     }
     //fetchTicketNotes();
     return ticket;       
    }
    
    //Fetch Ticket Notes
    public static TicketComment[] fetchTicketNotes(string ticketId){
        if(isApexTest){
            ticket_response = '{"responder_name":"Sathappan","subject":"This is a sample ticket","frDueBy":"2011-05-02T17:51:46+05:30","firstname_8":"Kolaveri","custom_field":{"firstname_8":"Kolaveri","mfr_8":null,"model_8":null,"lastname_8":"Boys","city_8":"item 1","type_8":null,"country_8":null,"state_8":"subcategory 1"},"urgent":false,"spam":false,"attachments":[{"attachment_url":"https://cdn.test.com","content_file_name":"testpng","content_content_type":"png"}],"trained":false,"status":2,"due_by":"2011-05-10T11:51:46+05:30","cc_email":null,"ticket_type":"Question","priority":1,"model_8":null,"mfr_8":null,"lastname_8":"Boys","deleted":false,"city_8":"item 1","to_email":null,"isescalated":true,"priority_name":"Low","responder_id":11576,"group_id":17,"fr_escalated":true,"notes":[{"user_id":11576,"notable_id":443,"body_html":"<p>Note Sample</p>","body":"Note Sample","incoming":false,"deleted":false,"updated_at":"2012-05-29T18:44:45+05:30","notable_type":"Helpdesk::Ticket","source":2,"private":true,"created_at":"2012-05-29T18:44:45+05:30","id":4080,"attachments":[{"attachment_url":"https://cdn.test.com","content_file_name":"testpng","content_content_type":"png"}]}],"updated_at":"2012-05-29T18:44:45+05:30","delta":false,"source":2,"description":"This is a sample ticket, feel free to delete it.","type_8":null,"owner_id":null,"email_config_id":null,"display_id":1,"description_html":"This is a sample ticket, feel free to delete it.","created_at":"2011-04-28T11:51:48+05:30","status_name":"Open","state_8":"subcategory 1","requester_id":115,"id":443,"country_8":null}';
        }
        string ticketRes = ticket_response;
        
        
        HttpRequest req = new HttpRequest();
         req.setMethod('GET');
         req.setEndpoint(url + '/helpdesk/tickets/' + ticketId + '.json');
         Blob headerValue = Blob.valueOf(apikey + ':' + pwd);
         String authorizationHeader = 'Basic ' +
         EncodingUtil.base64Encode(headerValue);
         req.setHeader('Authorization', authorizationHeader);
         Http http = new Http();
         if(!(Test.isRunningTest())){
            HTTPResponse res = http.send(req);
            if(res.getHeader('Content-Type') == 'text/html; charset=utf-8')
                return null;
            ticketRes = res.getBody();
        }
        
        else{
            ticketRes = '{"helpdesk_ticket":{"cc_email":{},"notes":[{"note":{"body":"test","body_html":"test_html","deleted":false,"id":1033983131,"incoming":false,"private":true,"source":4,"updated_at":"2015-04-20T15:21:54+05:30","user_id":1003509194,"attachments":[{"content_content_type":"application/pdf","content_file_name":"test.pdf","content_file_size":2217,"id":1020460583,"attachment_url":"https://s3.amazonaws.com/cdn.freshdesk.com"}]}},{"note":{"body":"test","body_html":"test_html","deleted":false,"id":1034103364,"incoming":false,"private":false,"source":0,"updated_at":"2015-04-21T10:07:10+05:30","user_id":1003165614,"attachments":[]}},{"note":{"body":"test","body_html":"test_html","deleted":false,"id":1034103364,"incoming":false,"private":false,"source":0,"updated_at":"2015-04-21T10:07:10+05:30","user_id":1003165614,"attachments":[]}},{"note":{"body":"test","body_html":"test_html","deleted":false,"id":1034103364,"incoming":false,"private":false,"source":0,"updated_at":"2015-04-21T10:07:10+05:30","user_id":1003165614,"attachments":[]}},{"note":{"body":"test","body_html":"test_html","deleted":false,"id":1034103364,"incoming":false,"private":false,"source":0,"updated_at":"2015-04-21T10:07:10+05:30","user_id":1003165614,"attachments":[]}}]}}';
            
        }
        
        JSONParser parser = JSON.createParser(ticketRes);
        //System.debug(LoggingLevel.INFO,'Ticket notes Response in FDUtility == '+ ticketRes);
        ticket_comment = new TicketComment();
        Integer i=0; 
        ticket_notes = new List<TicketComment>();
        while (parser.nextToken() != null) 
        {
            if(parser.getText() == 'notes'){

                if (parser.nextToken() == JSONToken.START_ARRAY)  
            {  
                while (parser.nextToken() !=  JSONToken.END_ARRAY)  
                {
                    if (parser.getCurrentToken() == JSONToken.START_OBJECT)  
                    {     
                        ticket_comment = new TicketComment();
                        
                        while (parser.nextToken() !=  JSONToken.END_OBJECT)  
                        {     
                            
                            if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'body_html'))  
                            {
                                parser.nextToken();
                                //boolean isHtmlSecure  = isHTMLDataVulnerable(parser.getText());
                                //ticket_comment.comment = (isHtmlSecure) ? ESAPI.encoder().SFDC_HTMLENCODE(parser.getText()) : parser.getText();
                                ticket_comment.comment = parser.getText();
                            }
                            if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'updated_at'))  
                            {
                                parser.nextToken();
                                
                                ticket_comment.updatedAt = formatUTCDate(parser.getText());
                            }
                            if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'user_name'))  
                            {
                                parser.nextToken();
                                ticket_comment.user = parser.getText();
                            }
                            if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'source'))  
                            {
                                parser.nextToken();
                                ticket_comment.source = parser.getText(); 
                            }
                            
                            if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'incoming'))  
                            {
                                parser.nextToken();
                                Boolean tmpString = parser.getBooleanValue();
                                ticket_comment.user_type = tmpString ? 'requester' : 'agent' ; 
                            }
                            if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'deleted'))  
                            {
                                parser.nextToken();
                                Boolean delNote = parser.getBooleanValue();
                                ticket_comment.deleted = delNote;
                            }
                            if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'private'))  
                            {
                                parser.nextToken();
                                Boolean noteType = parser.getBooleanValue();
                                ticket_comment.is_private = noteType;
                            }
                            if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'attachments'))
                            {
                                att = new List<Attachments>();
                                integer c = 0;
                                if(parser.nextToken() == JSONToken.START_ARRAY)
                                {
                                        
                                    while(parser.nextToken() != JSONToken.END_ARRAY)
                                    {
                                        if(parser.getCurrentToken() == JSONToken.START_OBJECT)
                                        {
                                            Attachments atts = new Attachments();
                                            while(parser.nextToken() != JSONToken.END_OBJECT)
                                            {
                                                if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'attachment_url'))  
                                                {
                                                    parser.nextToken();
                                                    atts.attachment_url = parser.getText(); 
                                                }
                                                if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'id'))  
                                                {
                                                    parser.nextToken();
                                                    atts.attachment_id = parser.getText(); 
                                                }
                                                if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'content_file_name'))  
                                                {
                                                    parser.nextToken();
                                                    atts.content_file_name = parser.getText(); 
                                                }
                                                if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'content_content_type'))  
                                                {
                                                    parser.nextToken();
                                                    atts.content_file_type = parser.getText(); 
                                                }   
                                            }
                                            
                                            att.add(atts);
                                            c++;    
                                        }
                                        
                                    }
                                    
                                }
                            ticket_comment.attachments = att;   
                            }
                        }
                        if(ticket_comment.comment != null){
                            if(!ticket_comment.comment.contains('user_agent: '))
                                ticket_notes.add(ticket_comment);   
                        }
                        
                    }
                    
                    i++;  
                }
                
            }               

            }
             
        }
        
        if(ticket_notes.size() >= 1){
            ticket_notes.remove(0);
        }
        
        return ticket_notes;
    }
    
   
    
    
    //Create Ticket
    public static remoteObject createTicket(string dataString, string updateFlag, string ticketId, string eMail)
    {
        System.debug('FDButility - createTicket - updateFlag' + updateFlag+'emailid '+eMail + 'datastring' + dataString);
        string requestMethod;
        string requestBody;
        string subject, status, priority, description, ticket_type, reqEndpoint, agent, group_id;
        remoteObject returnObj = new remoteObject();
        returnObj.success = true;
        returnObj.message = 'Ticket Created';
        CustomFields[] custFields = null;
        List<CustomFields> nestedFieldsList=new List<CustomFields>();
        if(!isApexTest){
            custFields  = populateCustomFields();
            //nested_fields
            for(CustomFields field:custFields){
                if(field.isNestedField){
                    for(CustomFields nestedField:field.nestedFields){
                        //System.debug('Nested fields in FDUtility'+'  '+nestedField.field_name);
                        nestedFieldsList.add(nestedField);
                    }
                }
            }
            
            
            System.debug('custFields ' + custFields);
            if(custFields == null){
                returnObj.success = false;
                returnObj.data = 'Unable to update the ticket. Please verify your apikey and domain URL and try again.';
                return returnObj;
            }
            
            if(nestedFieldsList.size()>0){
                custFields.addAll(nestedFieldsList);
            }   
        }
        
        try
        {
            if(isApexTest)
                dataString = 'subject=hello&status=2&priority=1&description_html=test desc&ticket_type=Lead&agent=1&group=1&other2_123875=subcategory1&other3_123875=item1';
                map<string,string> formData = deserializeString(dataString);
                
                remoteObject commentStatus;
                subject = ESAPI.encoder().SFDC_HTMLENCODE(formData.get('subject'));
                status = ESAPI.encoder().SFDC_HTMLENCODE(formData.get('status'));
                priority = ESAPI.encoder().SFDC_HTMLENCODE(formData.get('priority'));
                //string dueDate = formData.get('dueDate');
                description = replaceBadHtml(formData.get('description_html'));
                ticket_type = ESAPI.encoder().SFDC_HTMLENCODE(formData.get('ticket_type'));
                agent = ESAPI.encoder().SFDC_HTMLENCODE(formData.get('agent'));
                group_id = ESAPI.encoder().SFDC_HTMLENCODE(formData.get('group'));
                /*System.debug('formdata agent ' + formData.get('agent'));
                System.debug('Agent '+ agent); 
                System.debug('status after encoding ' + ESAPI.encoder().SFDC_HTMLENCODE(status));   
                System.debug('description after encoding' +ESAPI.encoder().SFDC_HTMLENCODE(description) );*/
            //Adding the custom fields to xml payload
            
            string[] fields_xml = dataString.split('&');
            
            string custom_xml = '<custom_field>';
            
            if(Test.isRunningTest()){
            custFields=populateCustomFields();
            }
            
            string[] key_value;
            for(integer i=0; i<fields_xml.size(); i++){
                
                if(!fields_xml[i].startsWith('subject') && !fields_xml[i].startsWith('description_html') && !fields_xml[i].startsWith('ticket_type') && !fields_xml[i].startsWith( 'priority') && !fields_xml[i].startsWith('status') && !fields_xml[i].startsWith('group') && !fields_xml[i].startsWith('agent')){
                    
                    key_value = fields_xml[i].split('=');
                    
                    if(key_value.size() > 1){
                        for(integer j=0; j< custFields.size(); j++){
                            if(custFields[j] != null){
                                if(custFields[j].field_name == key_value[0]){
                                    if(key_value[1] == 'N/A'){
                                        key_value[1]=' ';
                                    }
                                    custom_xml += ('<' + key_value[0] +'><![CDATA[' + EncodingUtil.urlDecode(ESAPI.encoder().SFDC_HTMLENCODE(key_value[1]), 'UTF-8') + ']]></' + key_value[0] + '>');
                                    continue;       
                                }   
                            }
                            
                        }   
                    }
                    
                }
            }
            System.debug('In fdutility update form'+' '+custom_xml);
            custom_xml += '</custom_field></helpdesk_ticket>';
            returnObj.message = custom_xml;
            String password;
            //Sending the updated ticket to FD
            if(updateFlag == 'true'){
                requestMethod = 'PUT';
                requestBody = '<helpdesk_ticket><status>'+ status +'</status><priority>'+ priority +'</priority><ticket_type>'+ ticket_type +'</ticket_type><responder_id>'+ agent +'</responder_id><group_id>'+ group_id +'</group_id>';
                System.debug('updateflag is true');
                System.debug('request body = ' + requestBody);
                
                
                reqEndpoint = url + '/helpdesk/tickets/'+ ticketId +'.xml';
                password = assume_pwd;
                returnObj.data = 'Ticket Updated';
            }else{
                System.debug('Inside ELSE ---------' + agent);
                requestMethod = 'POST';
                requestBody = '<helpdesk_ticket><email>' + eMail + '</email><subject>' + subject + '</subject><description_html><![CDATA['+ description +']]></description_html><status>'+ status +'</status><priority>'+ priority +'</priority><ticket_type>'+ ticket_type +'</ticket_type><responder_id>'+ agent +'</responder_id><group_id>'+ group_id +'</group_id>';
                System.debug('request body ' + requestBody);
                password = 'x';
                reqEndpoint = url + '/helpdesk/tickets.xml';
            }    
             HttpRequest req = new HttpRequest();
             req.setMethod(requestMethod);
             req.setEndpoint(reqEndpoint);
             req.setHeader('Content-Type','text/xml;charset=UTF-8');
             string reqData = requestBody + custom_xml;
             //string reqData = requestBody + '</helpdesk_ticket>';
             System.debug('Final Req Data ' + reqData);
             //reqData = '<![CDATA[' + reqData + ']]';
             req.setBody(reqData);
             String username = apikey;
             //System.debug('username ' + username + 'password ' + password);
             Blob headerValue = Blob.valueOf(username + ':' + password);
             String authorizationHeader = 'Basic ' +
             EncodingUtil.base64Encode(headerValue);
             req.setHeader('Authorization', authorizationHeader);
             Http http = new Http();
             string resData = null;
             HTTPResponse res = null;
             if(!isApexTest){
                res = http.send(req);
                resData = res.getBody();   
                //System.debug('```resData' + resData); 
             }else{
                resData = '<helpdesk-tickets type="array"><helpdesk-ticket><account-id type="integer">1</account-id><cc-email type="yaml" nil="true"></cc-email><created-at type="datetime">2011-03-29T12:17:01+05:30</created-at><deleted type="boolean">false</deleted><delta type="boolean">true</delta><description>This is a sample ticket, feel free to delete it.</description><display-id type="integer">1</display-id><due-by type="datetime">2011-04-08T12:16:59+05:30</due-by></helpdesk-ticket></helpdesk-tickets>';
             }
             
             
             //returnObj.data = res.getBody();
             if(resData != '' && resData != ' ' && resData != null){
                string testStr = null;
                if(!isApexTest1)
                    testStr = '<display-id type="integer">';
                 integer idIndex = resData.indexOf(testStr);
                 integer idEndIndex = resData.indexOf('</display-id>');
                 if(updateFlag != 'true'){
                    string ticketIdRes = resData.substring((idIndex+testStr.length()), idEndIndex);
                    returnObj.data = String.valueOf(ticketIdRes);   
                 }
                 else{
                    returnObj.data = 'Object Updated';
                 }  
             }
             returnObj = handleAssumeIdentityError(returnObj, res.getHeader('Content-Type'), res.getStatusCode(), res.getBody());
            //System.debug('Final returnObj' + returnObj); 
        }
        catch(exception e)
        {   
            returnObj.success = false;
            returnObj.message = 'Ticket Creation Failed';
            returnObj.data = e.getMessage();
            System.debug(LoggingLevel.ERROR, returnObj.data);
        }
        
        
        return returnObj;       
    }
    
    //Add Ticket Notes
    public static remoteObject addComment(string ticketId, string note, string noteType, string[] notify_emails){
        //List<string> notify_email_array = new List<string>();
        //string[] notify_emails = new String[]{'sathappan@freshdesk.com'};
        if(!isApexTest){
            map<string,string> formData = deserializeString(note);
            note = formData.get('comment').trim();
            note = note.replace('\\','\\\\').replace('"','\\"');
            
        }
        else
            note = 'comment=Test&subject=&description=&status=2&priority=1 ';
            //note = 'Test Boy Comment';
            
        remoteObject returnObj = new remoteObject();
        returnObj.success = true;
        returnObj.message = 'Comment Added';
        returnObj.data = 'Comment Added';
         try{
                 HttpRequest req = new HttpRequest();
                 req.setMethod('POST');
                 req.setEndpoint(url + '/helpdesk/tickets/'+ ticketId +'conversations/notes.json');
                 //req.setHeader('Content-Type','text/xml;charset=UTF-8');
                 req.setHeader('Content-Type','application/json');
                 //note = '<![CDATA[' + note + ']]>';
                 req.setBody('{"notify_emails":'+ JSON.serialize(notify_emails) +',"helpdesk_note":{"body_html":"'+ replaceBadHtml(note) +'", "private": "'+ noteType + '", "source": "2"}}');
                 //req.setBody('<helpdesk_note><source>2</source><private type="boolean">'+ noteType +'</private><body_html >'+ note +'</body_html></helpdesk_note>');
                 Blob headerValue = Blob.valueOf(apikey + ':' + assume_pwd);
                 String authorizationHeader = 'Basic ' +
                 EncodingUtil.base64Encode(headerValue);
                 req.setHeader('Authorization', authorizationHeader);
                 Http http = new Http();
                 HTTPResponse res = http.send(req);
                 returnObj = handleAssumeIdentityError(returnObj, res.getHeader('Content-Type'), res.getStatusCode(), res.getBody());
                 
         }
         catch(exception e){
                returnObj.success = false;
                returnObj.message = 'Unable to add comment';
                returnObj.data = e.getMessage();
         }
                
        
        return returnObj;
    }
    
    public static CustomFields[] populateCustomFields(){
        List<CustomFields> cf = new List<CustomFields>();
        //System.debug('populateCustomFields - url ' + url);
        try{
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(url + '/ticket_fields.xml');
            Blob headerValue = Blob.valueOf(apikey + ':' + pwd);
            String authorizationHeader = 'Basic ' +
            EncodingUtil.base64Encode(headerValue);
            req.setHeader('Authorization', authorizationHeader);
            Http http = new Http();
            string response;
            HTTPResponse res;
            integer i = 0;
           // System.debug('req - CF ' + req);
           // System.debug('isApexTest ' + isApexTest);
            System.debug(LoggingLevel.ERROR, req);
            if(!(Test.isRunningTest())){
                res = http.send(req);
                response = res.getBody();
            }
            else{
            response =  '<helpdesk-ticket-fields type="array"><helpdesk-ticket-field><field-options nil="true"/><field-type>nested_field</field-type><label>Agent</label><name>agent</name><required type="boolean">false</required><nested_ticket_fields><nested_ticket_field><id>1000004467</id><name>other2_123875</name><label>Other2</label><label_in_portal>Other2</label_in_portal><level>2</level></nested_ticket_field><nested_ticket_field><id>1000004467</id><name>other3_123875</name><label>Other3</label><label_in_portal>Other3</label_in_portal><level>3</level></nested_ticket_field></nested_ticket_fields><choices><option><id>roshini</id><value>1003165614</value><choices><option><id>1002771300</id><value>subcategory1</value><choices><option><id>1002771301</id><value>item1</value></option></choices></option></choices></option></choices></helpdesk-ticket-field><helpdesk-ticket-field><field-type>custom_dropdown</field-type><id type="integer">1000579147</id><label>Preference</label><name>preference_123875</name><required type="boolean">true</required><choices><option><id>High</id><value>High</value></option><option><id>Low</id><value>Low</value></option></choices></helpdesk-ticket-field></helpdesk-ticket-fields>';               
            }
            //System.debug('Response - ' + response);
            
            DOM.Document doc = new DOM.Document();     
            doc.load(response);
            DOM.XMLNode root = doc.getRootElement();
            cf = walkThrough(root);
        }
        catch(Exception e){
            cf = new List<CustomFields>();  // Make it an empty list instead of null - hrishikesh
        }
        System.debug('cf ' + cf);
        return cf;
    }
    
    public static List<CustomFields> walkThrough(DOM.XMLNode node) {
        string field_name, field_label, field_type;
        string firstLevelOpt, secondLevelOpt;
        boolean field_required;
        List<CustomFields> cf = new List<CustomFields>();
        List<CustomFields> nestedFieldList;
        List<FieldOptions> fOptions;
        boolean thirdNestedOption=false;
        for (Dom.XMLNode child: node.getChildElements()) {
            //System.debug('node type ' + child.getNodeType());
          if (child.getNodeType() == DOM.XMLNodeType.ELEMENT) {
            //System.debug('Child Name ' + child.getName());
            if(child.getName() == 'helpdesk-ticket-field'){
                //System.debug('inside if helpdesk-ticket-field');
                for (Dom.XMLNode field: child.getChildElements()) {
                    if(field.getName() == 'name'){
                        field_name = field.getText();
                    }
                    else if(field.getName() == 'label'){
                        field_label = field.getText();      
                    }
                    else if(field.getName() == 'field-type'){
                        field_type = field.getText();
                    }
                    else if(field.getName() == 'required'){
                        field_required = field.getText().equalsIgnoreCase('true');
                    }
                    else if(field.getName() == 'choices'){
                        fOptions = new List<FieldOptions>();
                        for (Dom.XMLNode choice: field.getChildElements()) {
                            if(choice.getName() == 'option'){
                                FieldOptions fopt  = new FieldOptions();
                                for (Dom.XMLNode option: choice.getChildElements()) {
                                    if(option.getName() == 'id'){
                                        fopt.id = option.getText();
                                    }else if(option.getName() == 'value'){
                                        fopt.value = option.getText();
                                        firstLevelOpt=option.getText();
                                    }
                                    else if(option.getName() == 'choices'){               //dependent dropdowns
                                       List<FieldOptions> nestOptions = new List<FieldOptions>();
                                       Map<string,List<FieldOptions>> dependentOptions = new Map<string,List<FieldOptions>>();
                                       for (Dom.XMLNode nestchoice: option.getChildElements()) {
                                        if(nestchoice.getName() == 'option'){
                                            FieldOptions dependOpt  = new FieldOptions();
                                            for (Dom.XMLNode nestoption: nestchoice.getChildElements()) {
                                                if(nestoption.getName() == 'id'){
                                                     dependOpt.id = nestoption.getText();
                                                }else if(nestoption.getName() == 'value'){
                                                     dependOpt.value = nestoption.getText();
                                                     secondLevelOpt= nestoption.getText();
                                                }
                                                 else if(nestoption.getName() == 'choices'){
                                                    thirdNestedOption=true;
                                                    List<FieldOptions> nestLevelTwoOpt = new List<FieldOptions>();
                                                    Map<string,List<FieldOptions>> dependLevelTwoOpts = new Map<string,List<FieldOptions>>();
                                                    for (Dom.XMLNode nestTwochoice: nestoption.getChildElements()) {
                                                        if(nestTwochoice.getName() == 'option'){
                                                            FieldOptions levelTwoOpt  = new FieldOptions();
                                                            for (Dom.XMLNode nestSecondoption: nestTwochoice.getChildElements()) {
                                                                if(nestSecondoption.getName() == 'id'){
                                                                   levelTwoOpt.id = nestSecondoption.getText();
                                                                }else if(nestSecondoption.getName() == 'value'){
                                                                   levelTwoOpt.value = nestSecondoption.getText();
                                                                }
                                                                
                                                            }
                                                            nestLevelTwoOpt.add(levelTwoOpt);
                                                        }
                                                    }
                                                    dependLevelTwoOpts.put(secondLevelOpt,nestLevelTwoOpt);
                                                    dependOpt.dependentFields=dependLevelTwoOpts;
                                                 }
                                            }
                                            nestOptions.add(dependOpt);
                                        }
                                       }
                                       dependentOptions.put(firstLevelOpt,nestOptions);
                                       fopt.dependentFields=dependentOptions;
                                      
                                    }
                                   
                                }
                                
                               // System.debug('fopt ' + fopt);
                                fOptions.add(fopt);
                            }
                        }
                        
                        if(field_type == 'custom_dropdown' || field_type == 'default_group' || field_type == 'default_agent')
                        {
                         FieldOptions fopt  = new FieldOptions();
                         fopt.id = 'N/A';
                         fopt.value = ' ';
                         fOptions.add(fopt);
                        }
                        
                        else if(field_type == 'nested_field')
                        {
                         FieldOptions keyopt  = new FieldOptions();
                         Map<String,List<FieldOptions>> optMap1=new Map<String,List<FieldOptions>>();
                         List<FieldOptions> optList1=new List<FieldOptions>();
                         keyopt.id = 'N/A';
                         keyopt.value = 'N/A';
                         FieldOptions firstkeyopt  = new FieldOptions();
                         Map<String,List<FieldOptions>> optMap2=new Map<String,List<FieldOptions>>();
                         List<FieldOptions> optList2=new List<FieldOptions>();
                         firstkeyopt.id = 'N/A';
                         firstkeyopt.value = 'N/A';
                         if(thirdNestedOption){
                         FieldOptions secondkeyopt  = new FieldOptions();
                         secondkeyopt.id = 'N/A';
                         secondkeyopt.value = 'N/A';
                         optList2.add(secondkeyopt);
                         optMap2.put(firstkeyopt.value,optList2);
                         firstkeyopt.dependentFields=optMap2;
                         thirdNestedOption=false;   
                         }
                         optList1.add(firstkeyopt);
                         optMap1.put(keyopt.value,optList1);
                         keyopt.dependentFields=optMap1;
                         fOptions.add(keyopt);
                        }
                       
                    }
                    
                    else if(field.getName() == 'nested_ticket_fields'){
                        nestedFieldList=new List<CustomFields>();
                       for(Dom.XMLNode nestedFields: field.getChildElements()){
                        if(nestedFields.getName() == 'nested_ticket_field'){
                            CustomFields nestedField=new CustomFields();
                            for(Dom.XMLNode nestedFieldValues: nestedFields.getChildElements()){
                                
                            if(nestedFieldValues.getName() == 'id'){
                            nestedField.field_id = nestedFieldValues.getText(); 
                            }   
                                
                            else if(nestedFieldValues.getName() == 'name'){
                            nestedField.field_name = nestedFieldValues.getText();
                            }
                            else if(nestedFieldValues.getName() == 'label'){
                            nestedField.field_label = nestedFieldValues.getText();      
                            }
                            
                            else if(nestedFieldValues.getName() == 'level'){
                            nestedField.field_level = nestedFieldValues.getText();      
                            }
                                
                            }
                            nestedFieldList.add(nestedField);
                        }
                       }
                    }
                }
                if(field_type!='nested_field'){
                    nestedFieldList=null;
                }
                cf.add(new CustomFields(field_label, field_name, field_type, field_required, fOptions, null,nestedFieldList));  
            }
          }
        }
        return cf;
    }
    
   public static FDContact getContactDetails(string id){
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(url + '/contacts/' + id + '.json');
        Blob headerValue = Blob.valueOf(apikey + ':' + pwd);
        String authorizationHeader = 'Basic ' +
        EncodingUtil.base64Encode(headerValue);
        req.setHeader('Authorization', authorizationHeader);
        Http http = new Http();
        string response = null;
        if(!(Test.isRunningTest())){
            HTTPResponse res = http.send(req);
            response = res.getBody();   
        }   
        else
            response = '{"user":{"updated_at":"2012-04-03T16:10:53+05:30","phone":null,"login_count":0,"last_login_ip":null,"current_login_ip":null,"single_access_token":"dsdasdasdUqH3az","posts_count":0,"fb_profile_id":null,"created_at":"2011-12-09T18:41:47+05:30","second_email":null,"mobile":null,"id":3200,"delta":false,"customer_id":null,"crypted_password":null,"last_login_at":null,"deleted":false,"user_role":3,"blocked_at":null,"failed_login_count":0,"description":null,"time_zone":"Chennai","persistence_token":"502f7d","language":"en","blocked":false,"active":false,"twitter_id":null,"perishable_token":"cbd","password_salt":null,"job_title":null,"import_id":null,"email":"rhel@freshdesk.com","address":null,"account_id":0,"name":"Rachel","last_seen_at":null,"current_login_at":null}}';
        JSONParser parser = JSON.createParser(response);
        FDContact fdContact = new FDContact();
        while (parser.nextToken() != null) {
            if (parser.getCurrentToken() == JSONToken.START_OBJECT)  
            {
                while (parser.nextToken() !=  JSONToken.END_OBJECT){
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'name')){
                        parser.nextToken();
                        fdContact.name = parser.getText();
                    }
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'id')){
                        parser.nextToken();
                        fdContact.id = parser.getText();
                    }
                    if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'email')){
                        parser.nextToken();
                        fdContact.email = parser.getText();
                    }
                }   
            }       
        }
        return fdContact;       
   }
    
    public static string formatUTCDate(string dateValue){
        string finalDate = dateValue.replace('T',' ');
        string newstr = finalDate.substring(0,19);
        datetime objdt  = datetime.valueof(newstr );
        string conDate = objdt.format('MMM dd, yyyy hh:mm a');
        return conDate;
    }
    
    //General Utility Methods
    
    public static remoteObject handleAssumeIdentityError(remoteObject returnObj, string header, integer statusCode, string resBody){
        System.debug('handleAssumeIdentityError remoteobj' + returnObj +'- header '+header +'status Code - ' +statusCode +'resbody '+resBody );
        if((header.contains('text/html')) && (statusCode != 200 || statusCode != 201) && statusCode != 406 && statusCode != 302 ){
            returnObj.data = 'Unable to update the ticket. Please verify if you have appropriate permissions to edit the ticket and try again.';
            returnObj.success = false;
         }
         else{
            if(statusCode == 401){
                string resData = resBody;
                returnObj.success = false;
                string testStr = null;
                /*if(!isApexTest1)
                    testStr = '<error-code>';
                integer idIndex = resData.indexOf(testStr);
                integer idEndIndex = resData.indexOf('</error-code>');
                string errorCode = resData.substring((idIndex+testStr.length()), idEndIndex);*/
                string errorCode;
                if(header.contains('text/html') == false && header.contains('application/xml') == false){
                    JSONParser parser = JSON.createParser(resBody);
                    while (parser.nextToken() != null) {
                        if (parser.getCurrentToken() == JSONToken.START_OBJECT)  
                        {
                            while (parser.nextToken() !=  JSONToken.END_OBJECT){
                                if((parser.getCurrentToken() == JSONToken.FIELD_NAME) &&(parser.getText() == 'error_code')){
                                    parser.nextToken();
                                    errorCode = parser.getText();
                                }           
                            }
                        }
                    }
                }
                else{
                    returnObj.data = 'Unable to update the ticket. Please verify your api key and domain url and retry.';
                    return returnObj;
                }
                
                if(errorCode == 'assuming_identity_user_does_not_exist')
                    returnObj.data = 'Error updating the ticket. Please verify if you are a valid agent in Freshdesk';
                else if(errorCode == 'assuming_identity_not_allowed')
                    returnObj.data = 'Error updating the ticket. Please confirm if the API key, provided during installation of the app, is a valid administator in Freshdesk';
                else
                    returnObj.data = 'Unable to update the ticket. Please verify your api key and domain url and retry.';
            }
         }
         return returnObj;    
   }
    
    public static Map<string,string> deserializeString(String argString)
    {     
        System.debug('deserialize String ' + argString);
        string[] params = argString.split('&');
        map<String,String>  formParams = new map<String,String>();
        for(string p : params)
        {   
            System.debug('params --- ' +  p);
            String encodeString = EncodingUtil.urlDecode(p.substring(p.indexOf('=')+1,p.length()),'UTF-8');
            //formParams.put(EncodingUtil.urlDecode(p.substring(0,p.indexOf('=')),'UTF-8'),EncodingUtil.urlDecode(p.substring(p.indexOf('=')+1,p.length()).replace('\r\n', ''),'UTF-8'));    
            formParams.put(EncodingUtil.urlDecode(p.substring(0,p.indexOf('=')),'UTF-8'),encodeString.replace('\r\n', ''));
            
        }        
        return formParams;
    }
    
    public static string replaceBadHtml(string dataStr){
        //if(data.contains('&lt;script&gt;') || data.contains('&lt;applet&gt;') || data.contains('&lt;body&gt;') || data.contains('&lt;embed&gt;') || data.contains('&lt;frame&gt;') || data.contains('&lt;script&gt;') || data.contains('&lt;frameset&gt;') || data.contains('&lt;html&gt;') || data.contains('&lt;iframe&gt;') || data.contains('&lt;img&gt;') || data.contains('&lt;layer&gt;') || data.contains('&lt;link&gt;') || data.contains('&lt;ilayer&gt;') || data.contains('&lt;meta&gt;') || data.contains('&lt;object&gt;'))
        //return true;
        if(dataStr != null){
            List<string> badHtml = new List<string>();
            badHtml.add('<script>');badHtml.add('<applet>');badHtml.add('<body>');badHtml.add('<embed>');badHtml.add('<frame>');badHtml.add('<frameset>');badHtml.add('<html>');badHtml.add('<iframe>');badHtml.add('<img>');badHtml.add('<layer>');badHtml.add('<link>');badHtml.add('<ilayer>');badHtml.add('<meta>');badHtml.add('<object>');
            badHtml.add('</script>');badHtml.add('</applet>');badHtml.add('</body>');badHtml.add('</embed>');badHtml.add('</frame>');badHtml.add('</frameset>');badHtml.add('</html>');badHtml.add('</iframe>');badHtml.add('</img>');badHtml.add('</layer>');badHtml.add('</link>');badHtml.add('</ilayer>');badHtml.add('</meta>');badHtml.add('</object>');
             
            for(integer c = 0; c < badHtml.size(); c++){
                if(dataStr.contains(badHtml.get(c))){
                    dataStr = dataStr.replaceAll(badHtml.get(c), ESAPI.encoder().SFDC_HTMLENCODE(badHtml.get(c)));
                }
            }   
        }
    return dataStr;
    
    }
    
    
    //Utility Test Methods
    public static void testGetAllTickets(){
        isApexTest = true;
        getAllTickets('rachel@freshdesk.com', 'email', 1);
    }
    
    public static void testFetchTicketDetails(){
        isApexTest = true;
        fetchTickets('1');
    }
    
    public static void testFetchTicketNotes(){
        isApexTest = true;
        fetchTicketNotes('11');
    }
    
    public static void testPopulateCustomFields(){
        isApexTest = true;
        List<CustomFields> cufields = populateCustomFields();
    } 
    
    public static void testAddComment(){
        isApexTest = true;
        addComment('1', 'Test Note', 'true', null);
    }
    
    public static void testCreateTicket(){
        isApexTest = true;
        createTicket('Dummy Data', 'false', '', '');
        testCreateTicketException();
    }
    
    public static void testUpdateTicket(){
        isApexTest = true;
        createTicket('Dummy Data', 'true', '1', 'dummy@fd.com');
    }
    
    public static void testCreateTicketException(){
        isApexTest = true;
        isApexTest1 = true;
        createTicket('Dummy Data', 'true', '1', 'dummy@fd.com');
    }
    
    public static void testFetchContactsFD(){
        isApexTest = true;
        getContactDetails('3200');
    }
    
    

}