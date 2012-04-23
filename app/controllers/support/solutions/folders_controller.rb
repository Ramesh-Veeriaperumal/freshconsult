class Support::Solutions::FoldersController < Support::SupportController
	before_filter :scoper
 
	private
	def scoper
		@folder = current_account.folders.find_by_id(params[:id])
	end
end