global with sharing class AccountSettings {
	
	private static boolean isApexTest1 = false;
	private static boolean isApexTest2 = false;
	private static boolean isApexTest3 = false;
	public static string api_key{get; set;}
	public static string fd_url{get; set;}
	
	static{
		RemoteAuth__c site = RemoteAuth__c.getOrgDefaults();
		api_key = (site.fd_username__c == null) ? '' : site.fd_username__c;
		fd_url = (site.fd_url__c == null) ? '' : site.fd_url__c;
	}
	
	@remoteAction
    global static remoteObject saveRemoteSettings(string url, string apikey)
    {
        remoteObject returnObj = new remoteObject();
        returnObj.success = true;
        returnObj.message = 'Authenticated Successfully';
        returnObj.data = 'Authenticated Successfully';
        
        try
        {   
             HttpRequest req = new HttpRequest();
		     req.setMethod('GET');
		     req.setEndpoint(url + '/helpdesk/tickets.json?filter_name=unresolved');
		     
		     Blob headerValue = Blob.valueOf(apikey + ':x');
		     System.debug(LoggingLevel.ERROR, headerValue);
		     String authorizationHeader = 'Basic ' +
		     EncodingUtil.base64Encode(headerValue);
		     req.setHeader('Authorization', authorizationHeader);
		     req.setHeader('Content-Type', 'application/xml');
		     Http http = new Http();
		     integer statusCode;
		     if(!isApexTest1 && !isApexTest2){
		     	HTTPResponse res = http.send(req);
		     	System.debug(LoggingLevel.ERROR, res);
		     	statusCode = res.getStatusCode();
		     	System.debug(LoggingLevel.ERROR, statusCode);
		     }
		     else if(isApexTest1){
		     	statusCode = 200;
		     }
		     else if(isApexTest2){
		     	statusCode = 401;
		     }
		     else if(isApexTest3){
		     	throw new System.NullPointerException();
		     }
		     if(statusCode == 200){
		     	RemoteAuth__c site = RemoteAuth__c.getOrgDefaults();
		     	site.fd_url__c = url;
				site.fd_username__c = apikey;
				site.SetupOwnerId = UserInfo.getOrganizationId();
				
		     	if(site == null){
		     		insert(site);
		     	}else{
		     		upsert(site);
		     	}
		    
		     }else{
		     	returnObj.success = false;
            	returnObj.data = 'Unable to connect to Freshdesk. Please check the domain URL and credentials.';
		     }
		     
        }
        catch(exception e)
        {
        	returnObj.success = false;
            returnObj.data = e.getMessage();
            returnObj.message = e.getMessage();
        }
         return returnObj;       
	}
    
    public static void testAcc(){
    	isApexTest1 = true;
    	saveRemoteSettings('https://testertest.freshdesk.com', 'sathappan@freshdesk.com');
    	isApexTest1 = false;
    }
    
    public static void testUnauthorizedAcc(){
    	isApexTest2 = true;
    	saveRemoteSettings('https://testertest.freshdesk.com', 'sathappan@freshdesk.com');
    	isApexTest2 = false;
    }
    
    public static void testAccException(){
    	isApexTest3 = true;
    	saveRemoteSettings('https://testertest.freshdesk.com', 'sathappan@freshdesk.com');
    	isApexTest3 = false;
    }
    
    

}