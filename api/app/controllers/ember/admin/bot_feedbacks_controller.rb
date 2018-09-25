module Ember
  module Admin
    class BotFeedbacksController < ApiApplicationController
      include HelperConcern
      include DeleteSpamConcern

      before_filter :load_bot
      before_filter :set_solutions_klasses, only: [:bulk_map_article, :create_article]
      before_filter :has_publish_solution_privilege, only: [:bulk_map_article, :bulk_delete, :create_article]

      def bulk_map_article
        return unless validate_body_params
        delegator_hash = { article_id: cname_params[:article_id], category_ids: @bot.category_ids }
        return unless validate_delegator(nil, delegator_hash)
        fetch_objects
        validate_and_map_items(cname_params[:article_id]) if @items.present?
        render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors)
      end

      def create_article
        return unless validate_body_params
        return unless validate_delegator(nil, folder_id: cname_params[:folder_id])
        fetch_objects
        return render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors) if @items.blank?
        article = Solution::Builder.article(solution_article_meta: article_meta_hash)
        if article.errors.blank?
          validate_and_map_items(article.id)
          render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors)
        else
          render_errors(article.errors)
        end
      end

      private

        def set_solutions_klasses
          @delegator_klass = BotConstants::SOLUTION_DELEGATOR_CLASS
          @validation_klass = BotConstants::SOLUTION_VALIDATION_CLASS
        end

        def has_publish_solution_privilege
          render_request_error(:access_denied, 403) unless current_user.privilege?(:publish_solution)
        end

        def primary_article_hash
          {
            title: cname_params[:title],
            description: cname_params[:description],
            user_id: current_user.id,
            status: Solution::Constants::STATUS_KEYS_BY_TOKEN[:published]
          }
        end

        def article_meta_hash
          {
            primary_article: primary_article_hash,
            solution_folder_meta_id: cname_params[:folder_id],
            art_type: Solution::Constants::TYPE_KEYS_BY_TOKEN[:permanent]
          }
        end

        def destroy_item(item)
          return false unless validate_item(item)
          item.deleted!
        end

        def map_article(bot_feedback, article_id)
          bot_feedback.build_feedback_mapping(article_id: article_id)
          bot_feedback.state = BotFeedbackConstants::FEEDBACK_STATE_KEYS_BY_TOKEN[:mapped]
          bot_feedback.save
        end

        def validate_item(item)
          @delegator = BotFeedbackConstants::DELEGATOR_CLASS.constantize.new(item)
          unless @delegator.valid?(action_name.to_sym)
            (@validation_errors ||= {})[item.id] = @delegator
            return false
          end
          true
        end

        def load_objects
          @items = @bot.bot_feedbacks.preload(ticket: { requester: [ { user_companies: { company: :avatar } }, :avatar] })
          load_unanswered
          response.api_meta = { count: @unanswered_list.count }
        end

        def load_bot
          @bot = current_account.bots.find_by_id(params[:id])
          log_and_render_404 unless @bot
        end

        def constants_class
          'BotFeedbackConstants'.freeze
        end

        def feature_name
          FeatureConstants::BOT
        end

        def validate_filter_params
          validate_query_params
        end

        def load_unanswered
          useful              = params[:useful] ? params[:useful] : [BotFeedbackConstants::FEEDBACK_USEFUL_KEYS_BY_TOKEN[:default], BotFeedbackConstants::FEEDBACK_USEFUL_KEYS_BY_TOKEN[:no]]
          category            = BotFeedbackConstants::FEEDBACK_CATEGORY_KEYS_BY_TOKEN[:unanswered]
          state               = BotFeedbackConstants::FEEDBACK_STATE_KEYS_BY_TOKEN[:default]
          conditions          = { bot_id: params[:id], state: state, category: category, useful: useful, received_at: (params[:start_at])..(DateTime.parse(params[:end_at]).end_of_day) }
          paginate_options    = { page: params[:page], per_page: 30 }
          @unanswered_list    = @items.where(conditions).order('received_at DESC').paginate(paginate_options)
        end

        def fetch_objects
          @items = @bot.bot_feedbacks.where(id: params[cname][:ids])
        end

        def validate_and_map_items(article_id)
          @items_failed = []
          @items.each do |item|
            @items_failed << item unless validate_item(item) && map_article(item, article_id)
          end
        end
    end
  end
end
