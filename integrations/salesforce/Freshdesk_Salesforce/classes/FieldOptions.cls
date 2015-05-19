public with sharing class FieldOptions {
	public string id{get; set;}
	public string value{get; set;}
	public string email{get; set;}
	public Map<String,List<FieldOptions>> dependentFields{get;set;}
	public boolean isNestedOption{
		get{
		  if(this.dependentFields!=null){
		  	return true;
		  }
		  else{
		  	return false;
		  }
		
		}
		set;}
}