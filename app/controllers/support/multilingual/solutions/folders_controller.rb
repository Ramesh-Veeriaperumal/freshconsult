class Support::Multilingual::Solutions::FoldersController < Support::Solutions::FoldersController
	private
		def scoper
			@folder = current_account.solution_folder_meta.find_by_id(params[:id])
			(raise ActiveRecord::RecordNotFound and return) if @folder.nil?

			@category = @folder.solution_category_meta
		end
end
