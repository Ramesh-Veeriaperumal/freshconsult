module CloudFilesHelper
	
	def build_cloud_files attachment_json
		attachment = ActiveSupport::JSON.decode attachment_json
		decoded_url = attachment['link']
    begin
      uri = URI.parse(decoded_url) 
      return {} unless (uri.kind_of?(URI::HTTP) || uri.kind_of?(URI::HTTPS))
    rescue 
      return {}
    end
		filename = attachment['name']
		application_id = Integrations::Application.find_by_name(attachment['provider']).id
		return {:url => decoded_url, :filename => filename,
            :application_id => application_id}
	end

	def attachment_builder model,normal_attachments,cloud_files_attachments
		build_cloud_files_attachments(model,cloud_files_attachments) if model.respond_to?(:cloud_files)
	    build_normal_attachments(model,normal_attachments) if model.respond_to?(:attachments)
	    return model
	end

	def build_normal_attachments model,attachments
		(attachments || []).each do |attach|
	      model.attachments.build(:content => attach[:resource], :description => attach[:description], :account_id => model.account_id)
	    end
	end

	def build_cloud_files_attachments model,attachments
		(attachments || []).each do |attachment_json|
	      result = build_cloud_files(attachment_json)
	      next if result.blank?
	      model.cloud_files.build(result)
	    end
	end

end