class Support::Solutions::FoldersController < SupportController
	before_filter :scoper
 	
 	def show
 	
 	end

	private
	def scoper
		@folder = current_account.folders.find_by_id(params[:id])
		@category = @folder.category
	end
end