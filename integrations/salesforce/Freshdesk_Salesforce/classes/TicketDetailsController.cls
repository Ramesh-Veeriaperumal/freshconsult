global with sharing class TicketDetailsController {
    public static boolean isApexTest=false;
    
    @remoteAction
    global static remoteObject updateAgent(string username, string password)
    {
        RemoteAuth__c site = RemoteAuth__c.getInstance();
        remoteObject returnObj = new remoteObject();
        try{
            site.fd_username__c = username;
            site.fd_password__c = password;
            upsert site;
            returnObj.data = username + ' logged in';
            returnObj.success = true;
            if(isApexTest){
                throw new System.NullPointerException();
            }
            
        } 
        catch (Exception ex) {
            returnObj.data = ex.getMessage();
            returnObj.success = false;
        }
        return returnObj;       
    }
    
     @remoteAction
    global static remoteObject addComment(string tId, string note, string noteType, string[] notify_emails ){
        remoteObject returnObj = FDUtility.addComment(tId, note, noteType, notify_emails);
        if(returnObj == null){
            returnObj.success = false;
            returnObj.data = 'Unable to add note to the ticket.';
        }   
        return returnObj;
    }
    
    @remoteAction
    global static remoteObject createTicket(string dataString, string updateFlag, string tId, string eMail)
    {
    	System.debug('TicketDetails controller create ticket ' + dataString + 'email - ' + eMail + 'ticketid '+tId +'isapextest '+isApexTest);
        remoteObject returnObj;
        if(!isApexTest)
            returnObj = FDUtility.createTicket(dataString, updateFlag, tId, eMail);
        else
            returnObj = null;
        if(returnObj == null){
            returnObj = new remoteObject();
            returnObj.data = 'Unable to create/update the ticket in Freshdesk.';
            returnObj.success = false;
        }   
        return returnObj;       
    }
    
    public static void testUpdateAgentException(){
        isApexTest=true;
        updateAgent('dsada','dasdasd');
    }
    
    public static void testInvalidRemoteObj(){
        isApexTest = true;
        createTicket('data', 'false', '', '');
    }
    

}