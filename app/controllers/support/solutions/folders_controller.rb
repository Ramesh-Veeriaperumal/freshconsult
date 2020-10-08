class Support::Solutions::FoldersController < SupportController
  include Solution::PathHelper

  before_filter :redirect_to_support, only: [:show], if: :facebook?
  before_filter :scoper, :check_folder_permission
  before_filter :check_version_availability, only: [:show]
  before_filter :render_404, unless: :folder_visible?, only: :show
  before_filter { |c| c.check_portal_scope :open_solutions }

  def show
    @page_title = @folder.name
    respond_to do |format|
      format.html {
        (render_404 && return) if @folder.is_default?
        load_agent_actions(agent_actions_path(@folder), :view_solutions)
        load_page_meta
        set_portal_page :article_list
      }
      format.xml { render xml: @folder.to_xml(include: :published_articles) }
      format.json { render json: @folder.as_json(include: :published_articles) }
    end
  end

  def redirect_to_support
    redirect_to "/support/solutions/folders/#{params[:id]}"
  end

  private

    def scoper
      @solution_item = @folder = current_account.solution_folder_meta.find_by_id(params[:id])

      @category = @folder.solution_category_meta if @folder
    end
    
    def load_page_meta
      @page_meta ||= {
        :title => @folder.name,
        :description => @folder.description,
        :canonical => support_solutions_folder_url(@folder, :host => current_portal.host)
      }
    end

    def check_folder_permission
      unless @folder.nil? || @folder.visible?(current_user)
        unless logged_in?
          store_location
          redirect_to support_login_path
        else
          flash[:warning] = t(:'flash.general.access_denied')
          redirect_to support_solutions_path
        end
      end
    end

    def folder_visible?
      @folder && @folder.visible_in?(current_portal)
    end

    def unscoped_fetch
      @folder = current_account.solution_folder_meta.unscoped_find(params[:id])
    end

    def default_url
      support_solutions_folder_path(@folder, :url_locale => current_account.language)
    end
end
