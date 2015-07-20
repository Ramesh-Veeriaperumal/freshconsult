module ApiDiscussions
  class CategoriesController < ApiApplicationController

    before_filter :load_object, except: [:create, :index, :route_not_found]
    before_filter :check_params, only: :update
    before_filter :validate_params, only: [:create, :update]
    before_filter :manipulate_params, only: [:create, :update]
    before_filter :build_object, only: [:create]
    before_filter :load_objects, only: [:index]
    before_filter :load_association, only: [:show]

    def forums
      @forums = paginate_items(load_association)
      render '/api_discussions/forums/forum_list' # Need to revisit this based on eager loading associations in show
    end

    private

      def feature_name
        FeatureConstants::DISCUSSION
      end

      def load_object
        @item = scoper.detect { |category| category.id == params[:id].to_i }
        unless @item
          head :not_found # Do we need to put message inside response body for 404?
        end
      end

      def load_association
        @forums = @item.forums
      end

      def validate_params
        params[cname].permit(*(DiscussionConstants::CATEGORY_FIELDS))
        category = ApiDiscussions::CategoryValidation.new(params[cname], @item)
        render_error category.errors unless category.valid?
      end

      def scoper
        create? ? current_account.forum_categories : current_account.forum_categories_from_cache
      end
  end
end
