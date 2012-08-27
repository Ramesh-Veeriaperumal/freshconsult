class Support::Solutions::FoldersController < SupportController
	before_filter :scoper
 	before_filter :only => :show do |c|
		c.send(:set_portal_page, :article_list)
	end

	private
		def scoper
			@folder = current_account.folders.find_by_id(params[:id])
			@category = @folder.category
		end
end