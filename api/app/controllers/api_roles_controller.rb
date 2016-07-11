class ApiRolesController < ApiApplicationController
  private

    def scoper
      current_account.roles_from_cache
    end

    def load_object
      @item = scoper.detect { |role| role.id == params[:id].to_i }
      log_and_render_404 unless @item
    end
end
