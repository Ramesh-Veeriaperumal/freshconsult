public class AllTicketsController {
    
    public List<Ticket> ticket_desc { get; set; }
    public List<Ticket[]> all_tickets = new List<Ticket[]>();
    public string errorMessage {get; set;}
    public boolean isLastPageAvailable {get; set;}
    public string email;
    
    public AllTicketsController(){
        errorMessage = '';
    }
    
    public PageReference tickets(){
        
        string site_Id = ApexPages.currentPage().getParameters().get('site_Id');
        string site_fd_url_c = ApexPages.currentPage().getParameters().get('site_fd_url_c');
        string site_fd_username_c = ApexPages.currentPage().getParameters().get('site_fd_username_c');
        boolean valid_fd = String.isNotBlank(site_Id) && String.isNotBlank(site_fd_url_c) && String.isNotBlank(site_fd_username_c);
        String reqType = ApexPages.currentPage().getParameters().get('reqType');
        System.debug('siteid' + site_Id);
        
        System.debug('site_fd_url' + site_fd_url_c);
        System.debug('site_fd_username_c' + site_fd_username_c);
        System.debug('req type' + reqType);
        if(reqType != 'Account'){
            reqType = 'email'; 
        }
        try{
            if(valid_fd){
                email = ApexPages.currentPage().getParameters().get('email');
                integer page = Integer.valueOf(ApexPages.currentPage().getParameters().get('current_page'));
                string pagination_type = ApexPages.currentPage().getParameters().get('type');
                
                if(all_tickets.size() > 0){
                    if(all_tickets.size() < page){
                        ticket_desc = fetch_ticket_pages(reqType, page);
                    }else{
                        ticket_desc = all_tickets.get(--page);
                        if(pagination_type == 'previous')
                            isLastPageAvailable = true;
                        else{
                            if(ticket_desc.size() == 5){
                                get_next_page(reqType, ++page);
                            }else{
                                isLastPageAvailable = false;    
                            }   
                        }
                    }
                }else{
                    ticket_desc = fetch_ticket_pages(reqType, page);
                }
            }else{
                errorMessage = 'Unable to reach your Freshdesk domain(' + site_fd_url_c + '). Please verify your APIKey and domain URL.';
                PageReference pageRef = ApexPages.CurrentPage();
                ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, 'Error: ' + errorMessage);
                ApexPages.addMessage(myMsg);    
            }   
        }
        catch(Exception ex){
            errorMessage = ex.getMessage();
            PageReference pageRef = ApexPages.CurrentPage();
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, 'Error: ' + errorMessage);
            ApexPages.addMessage(myMsg);
        }
        return null;
    }
    
    public List<Ticket> fetch_ticket_pages(string reqType, integer page){
        List<Ticket> ticket_desc_1 = FDUtility.getAllTickets(email, reqType, page);
        List<Ticket> ticket_desc_2 = FDUtility.getAllTickets(email, reqType, page+1);
        all_tickets.add(ticket_desc_1);
        if(ticket_desc_2.size() > 0){
            all_tickets.add(ticket_desc_2);
            isLastPageAvailable = true;
        }else{
            isLastPageAvailable = false;
        }
        return ticket_desc_1;
    }
    
    public void get_next_page(string reqType, integer page){
        List<Ticket> next_ticket_page = FDUtility.getAllTickets(email, reqType, page);
        if(next_ticket_page.size() > 0){
            all_tickets.add(next_ticket_page);
            isLastPageAvailable = true; 
        }else{
            isLastPageAvailable = false;
        }
    }
    
}
//    <apex:attribute name="ticket_desc" description=""  type="Ticket[]" required="true"/>