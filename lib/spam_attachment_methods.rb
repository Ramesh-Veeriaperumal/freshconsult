module SpamAttachmentMethods

	def backup_attachments post
		post.attachments.each_with_index.map do |att, i|
			resource = open(att.authenticated_s3_get_url)
			original_filename = resource.base_uri.path.split('/').last.gsub("%20"," ")
			filename = "#{i}_#{original_filename}"
			AwsWrapper::S3Object.store("#{cdn_folder_name}/#{filename}", resource, S3_CONFIG[:bucket])
			filename
		end
	end

	def processed_attachments
		return {} if (params[:post].blank? || params[:post][:attachments].blank?)
		{
			:folder => cdn_folder_name,
			:file_names => uploaded_attachments
		}
	end

	def uploaded_attachments
		params[:post][:attachments].each_with_index.map do |att, i|
			filename = "#{i}_#{att[:resource].original_filename}"
			AwsWrapper::S3Object.store("#{cdn_folder_name}/#{filename}", att[:resource], S3_CONFIG[:bucket])
			filename
		end
	end

	def move_attachments(attachments, published_post)
		folder = attachments['folder']
		(attachments['file_names'] || []).map do |file_name|
			s3_object = AwsWrapper::S3Object.find("#{folder}/#{file_name}", S3_CONFIG[:bucket])
			attachment = open(s3_object.url_for(:read, :expires => 1.hour))
			if attachment
				def attachment.original_filename; base_uri.path.split('/').last.split('?').first.split('_')[1..-1].join.gsub("%20"," "); end
			end
			published_post.attachments.build(:content => attachment , :account_id => Account.current.id)
		end
	end

	def cdn_folder_name
	  @cdn_folder_name ||= "spam_attachments/month_#{Time.now.utc.strftime('%Y_%m')}/acc_#{Account.current.id}/#{Time.now.utc.to_f * (10**7)}"
	end
end