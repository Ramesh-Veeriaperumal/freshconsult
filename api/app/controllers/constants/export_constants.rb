module ExportConstants
	LOAD_OBJECT_EXCEPT = [:ticket_activities].freeze
	DATA_TYPE_MAPPING  = {:Float => "Float", :FixNum => "Integer", :String => "String", :NilClass => "Null"}.freeze
end.freeze
