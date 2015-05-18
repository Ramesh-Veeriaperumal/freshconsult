public with sharing class AccountsController {
	
	private final Account account;
	public boolean valid_fd{get; set;}
    public string url{get; set;}
    public boolean valid_agent{get; set;}
    public string uname{get; set;}
    public string pwd{get; set;}
    public string accName{get; set;}
    public string accId{get; set;}
    public static RemoteAuth__c site{get; set;}
    public static boolean isApexTest = false;
    public boolean isPrevious = false;
	public boolean isNext = false; 
	public static integer page = 0; 
    public static boolean valid_agent{get; set;}
    public static string apikey{get; set;}
    public static string filter{get; set;}
    
    public AccountsController(ApexPages.StandardController stdController) {
        if(!isApexTest)
        	this.account = [select id, name from Account where id=:ApexPages.currentPage().getParameters().get('id')];
        else
        	this.account = (Account)stdController.getRecord();
        accName = account.name;
        accId = account.Id;
        site = RemoteAuth__c.getOrgDefaults();
        url = site.fd_url__c;
        uname = site.fd_username__c;
        pwd = site.fd_password__c;
        
    }
    
}