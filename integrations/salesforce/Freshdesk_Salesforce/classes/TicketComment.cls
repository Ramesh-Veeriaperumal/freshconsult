public with sharing class TicketComment {
	public string ticket{get; set;}
	public string comment{get; set;}
	public string user{get; set;}
	public string updatedAt{get; set;}
	public string user_type{get; set;}
	public boolean deleted{get; set;}
	public string source{get; set;}
	public boolean is_private{get; set;}
	public Attachments[] attachments{get; set;}
	
	
}