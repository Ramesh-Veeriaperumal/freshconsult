module Integrations::OutlookContacts::Constant

  FRESHDESK_FOLDER = "Freshdesk Contacts"

  MAPPED_FIELDS = [{"fd_field" => "email", "outlook_field" => "EmailAddresses"},{"fd_field" => "mobile", "outlook_field" => "MobilePhone1"},{"fd_field" => "phone","outlook_field" => "BusinessPhones"},{"fd_field" => "name", "outlook_field" => "DisplayName"}]

  OUTLOOK_METADATA = [

    {"vendorDisplayName" => "Full name", "vendorPath" => "DisplayName", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Title", "vendorPath" => "Title", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Yomi first name", "vendorPath" => "YomiGivenName", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Yomi last name", "vendorPath" => "YomiSurname", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Email", "vendorPath" => "EmailAddresses", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Business Phone", "vendorPath" => "BusinessPhones", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Mobile", "vendorPath" => "MobilePhone1", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Job title", "vendorPath" => "JobTitle", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Company", "vendorPath" => "CompanyName", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Department", "vendorPath" => "Department", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Office", "vendorPath" => "OfficeLocation", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Manager", "vendorPath" => "Manager", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Assistant", "vendorPath" => "AssistantName", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Yomi company", "vendorPath" => "YomiCompanyName", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Notes", "vendorPath" => "PersonalNotes", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Business Address Street", "vendorPath" => "Street", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Business Address City", "vendorPath" => "City", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Business Address State", "vendorPath" => "State", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Business Address PostalCode", "vendorPath" => "PostalCode", "vendorNativeType" => "String"},
    {"vendorDisplayName" => "Business Address Country", "vendorPath" => "CountryOrRegion", "vendorNativeType" => "String"}
  ]

  CUSTOM_FIELDS =  {"1001" => "text", "1002" => "phone_number", "1003" => "dropdown",
        "1004" => "number", "1005"  => "survey_radio", "1006" => "checkbox", "1007" => "date", 
        "1008" => "paragraph", "1009" => "url"}

  CONTACT_TYPES = { "1" => "text", "2" => "text", "3" => "email", "4" => "phone_number", "5" => "phone_number", 
        "6"=> "text", "7" => "text", "8" => "checkbox", "9" => "paragraph", "10" => "dropdown", "11" => "dropdown", 
        "12" => "text", "13" => "paragraph"}.merge!(CUSTOM_FIELDS)

  VALIDATOR = {"String" => ["text", "phone_number", "paragraph"]}

  FD_VALIDATOR = { "text" => ["String",], "email" => [],"phone_number" => ["String"],
                    "checkbox" => [], "paragraph" => ["String"], "dropdown" => [],
                    "number" => ["String"], "survey_radio" => [], "date" => ["datetimeoffset"],"url" => []}

end