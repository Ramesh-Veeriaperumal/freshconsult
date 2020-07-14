module Ember
  module Admin
    class BotFeedbacksController < ApiApplicationController
      include HelperConcern
      include DeleteSpamConcern

      before_filter :load_bot, unless: :skip_bot_load?
      before_filter :set_solutions_klasses, only: [:bulk_map_article, :create_article]
      before_filter :has_publish_solution_privilege, only: [:bulk_map_article, :bulk_delete, :create_article]
      before_filter :check_chat_history_launchparty, only: [:chat_history]

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

      def chat_history
        return unless validate_query_params
        # Initial api call will not have query id. We retrieve forward messages for initial call.
        chat_messages, end_of_message = params[:query_id].present? ? Freshbots::Bot.chat_messages(@item, params[:direction], false, params[:query_id]) : Freshbots::Bot.chat_messages(@item)
        @chat_history = parse_chat_history_response(chat_messages)
        response.api_meta = {end_of_message: true} if end_of_message
      rescue Exception => e
        Rails.logger.error "Chat history exception is #{e.message}, Account is #{current_account.id}, Unanswered question is #{@item.id}"
        NewRelic::Agent.notice_error(e)
        render_base_error(:internal_error,500)
      end

      private

        def scoper
          current_account.bot_feedbacks
        end

        def check_chat_history_launchparty
          render_request_error(:access_denied, 403) unless Account.current.launched?(FeatureConstants::BOT_CHAT_HISTORY)
        end

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

        def skip_bot_load?
          BotFeedbackConstants::SKIP_BOT_LOAD.include?(action_name)
        end

        def parse_chat_history_response(messages)
          messages.map do |msg|
            msg_hash =  {
                          ticket_msg_hash: msg['tcktMsgHsh'],
                          msg: msg['msg'],
                          author: msg['athr'],
                          date: msg['crtDtTmstmp']
                        }
            content_type = msg_content_type(msg)
            msg_hash[BotFeedbackConstants::MSG_CONTENT_TYPES[content_type][:response_key]] = parse_ticket_msg_options(msg, content_type) if content_type
            msg_hash[:unanswered] = true if unanswered?(msg)
            msg_hash
          end
        end

        def unanswered? msg
          msg['tcktMsgHsh'] == @item.query_id
        end

        def msg_content_type(msg)
          msg['tcktMssgptns'].first['cntntTyp'] if msg['tcktMssgptns'].present? && BotFeedbackConstants::MSG_CONTENT_TYPES.keys.include?(msg['tcktMssgptns'].first['cntntTyp'])
        end

        def parse_ticket_msg_options(msg, content_type)
          msg['tcktMssgptns'].map {|item|
            {
              display_text: item['displayText'],
              url: item['mtdt'][content_type][BotFeedbackConstants::MSG_CONTENT_TYPES[content_type][:url]]
            }
          }
        end
    end
  end
end
