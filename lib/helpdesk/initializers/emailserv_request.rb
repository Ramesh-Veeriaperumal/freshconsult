FD_EMAIL_SERVICE = (YAML::load_file(File.join(Rails.root, 'config', 'fd_email_service.yml')))[Rails.env]
EmailServRequest::Configuration.configure({
	:host=> FD_EMAIL_SERVICE["host"],
	:path=> FD_EMAIL_SERVICE["antivirus_urlpath"],
	:authorization=> FD_EMAIL_SERVICE["key"],
	:read_timeout=> FD_EMAIL_SERVICE["timeout"]
})