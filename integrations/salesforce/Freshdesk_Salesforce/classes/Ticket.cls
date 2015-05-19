global class Ticket {
	
	public string ticketId{get; set;}
	public string subject{get; set;}
	public string description{get; set;}
	public string description_html{get; set;}
	public string status{get; set;}
	public string status_id{get; set;}
	public string priority{get; set;}
	public string ticketType{get; set;}
	public string source{get; set;}
	public string dueDate{get; set;}
	public string createdAt{get; set;}
	public string updatedAt{get; set;}
	public string displayId{get; set;}
	public string responderName{get; set;}
	public string responderId{get; set;}
	public string groupId{get; set;}
	public string requester{get; set;}
	public string cc_email{get; set;}
	public string to_email{get; set;}
	public CustomFields[] custom_fields{get; set;}
	public Attachments[] attachment_list{get;set;}
	
	public Ticket(){
	}
	
	public Ticket(string tId, string subj, string tstatus, string tpriority, string upd){
		this();
		ticketId = tId;
		subject = subj;
		status = tstatus;
		priority = tpriority;
		updatedAt = upd;
	}
	
	

}