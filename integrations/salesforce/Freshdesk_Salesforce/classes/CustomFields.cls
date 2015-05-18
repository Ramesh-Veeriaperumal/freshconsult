public with sharing class CustomFields {
	public string field_label{get; set;}
	public string field_value{get; set;}
	public string field_name{get; set;}
	public string field_type{get; set;}
	public string field_id{get; set;}
	public string field_level{get; set;}
	public boolean field_required{get; set;}
	public FieldOptions[] options{get; set;}
	
	public CustomFields(){}
	public CustomFields(string flabel, string fname, string ftype, boolean frequired, FieldOptions[] foptions, string fvalue){
		this();
		field_label = flabel;
		field_name = fname;
		field_type = ftype;
		field_required = frequired;
		options = foptions;
		field_value = fvalue;
	}

}