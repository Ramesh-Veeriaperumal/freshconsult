account = Account.current

default_folder = Admin::CannedResponses::Folder.seed(:account_id) do |folder|
	folder.account_id = account.id
	folder.name = "General"
	folder.is_default = true
end