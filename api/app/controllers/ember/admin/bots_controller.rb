module Ember
  module Admin
    class BotsController < ApiApplicationController
      include HelperConcern
      include Helpdesk::IrisNotifications
      include ChannelAuthentication
      include BotHelper

      around_filter :handle_exception, only: [:mark_completed_status_seen, :enable_on_portal]
      before_filter :verify_create_bot_folder, only: [:create_bot_folder]
      before_filter :check_bot_email_feature, only: :update

      def index
        @bots = { onboarded: current_account.bot_onboarded?, products: current_account.bots_from_cache }
      end

      def new
        return unless validate_query_params
        return unless validate_delegator(nil, delegator_hash)
        @bot = {
          product: product_hash(@portal),
          all_categories: categories_list(@portal)
        }
        profile_settings = Bot.default_profile
        @bot = @bot.merge(profile_settings)
        @bot
      end

      def create
        return unless validate_body_params(@item)
        return unless validate_delegator(@item, delegator_hash)
        construct_attributes
        # Creating bot at Joehukum side
        create_bot if save_bot
      end

      def show
        return unless validate_query_params
      end

      def update
        return unless validate_query_params(@item)
        return unless validate_delegator(nil, params.merge(support_bot: @item))
        update_bot_attributes
        # Updating bot at Joehukum side
        if save_bot
          allow_bot_api? ? update_bot : (head 204)
        end
      end

      def map_categories
        return unless validate_body_params(@item)
        return unless validate_delegator(@item, params)
        @old_category_ids = @item.category_ids
        begin
          @item.category_ids = params[:category_ids]
          @item.last_updated_by = current_user.id
          ml_response = Ml::Bot.update_ml(@item)
          if ml_response == true
            @item.save!
            Rails.logger.info("Map categories action:: #{bot_info(@item)}")
            train_bot if @item.training_status.to_i == BotConstants::BOT_STATUS[:training_not_started]
            head 204
          else
            handle_category_mapping_failure(ml_response)
            render_request_error(:internal_error, 503)
          end
        rescue => e
          handle_category_mapping_failure(e)
          render_errors(@item.errors)
        end
      end

      def mark_completed_status_seen
        return unless validate_state(BotConstants::BOT_STATUS[:training_completed])
        @item.clear_status
        head 204
      end

      def enable_on_portal
        return unless validate_body_params
        @item.enable_in_portal = cname_params[:enable_on_portal]
        @item.save ? (head 204) : render_errors(@item.errors)
      end

      def bot_folders
        @bot_folder_groups = bot_folder_groups
      end

      def create_bot_folder
        @meta = Solution::Builder.folder(solution_folder_meta: params.except(:id))
        @meta.errors.any? ? render_errors(@meta.errors) : @folder_meta = {
          id: @meta.id, visibility: @meta.visibility, name: @meta.primary_folder.name}
      end

      def analytics
        return unless validate_query_params
        response, response_code = Freshbots::Bot.analytics(@item.external_id, params[:start_date], params[:end_date])
        if response_code == 200
          @analytics = transform_response(JSON.parse(response, symbolize_names: true)[:content][:stats])
        else
          error_msg = "BOT :: Analytics failure :: Account id : #{@item.account_id} :: Bot id : #{@item.id} :: Response :: #{response_code} :: #{response}"
          Rails.logger.error(error_msg)
          NewRelic::Agent.notice_error(error_msg)
          render_request_error(:internal_error, 503)
        end
      end

      def remove_analytics_mock_data
        return unless validate_body_params
        return unless validate_delegator(@item)
        @item.additional_settings.delete(:analytics_mock_data)
        if @item.save
          head 204
        else
          render_errors(@item.errors)
        end
      end

      private

        def construct_attributes
          @item.last_updated_by = current_user.id
          product = @portal.product
          @item.product_id = product.id if product
          @avatar = params['avatar']
          if @avatar['is_default']
            # Additional settings column contains info about default avatar
            # Custom avatar data will be taken from attachment table
            @item.additional_settings = {
              is_default: true,
              avatar_id: @avatar['avatar_id'],
              default_avatar_url: @avatar['url']
            }
          else
            update_logo
            @item.additional_settings = {
              is_default: false
            }
          end
        end

        def create_bot
          response, response_code = Freshbots::Bot.create_bot(@item)
          unless response_code == Freshbots::Bot::BOT_CREATION_SUCCESS_STATUS
            raise "error in creating bot at BOT-SIDE @@response -> #{response}"
          end
          @item.additional_settings[:bot_hash] = response['content']['botHsh']
          if @item.save
            @item.training_not_started!
            @bot = {
              id: @item.id
            }
            @bot
          else
            render_errors(@item.errors)
          end
        rescue => e
          Rails.logger.error "FRANKBOT-ERROR:  #{e.inspect}, bot_hash -> #{@item.additional_settings[:bot_hash]}, bot_id -> #{@item.id},external_id -> #{@item.external_id},
                              account_id -> #{current_account.id}, portal_id -> #{@item.portal_id}"
          render_base_error(:internal_error, 500)
          @item.destroy
        end

        def update_bot
          response, response_code = Freshbots::Bot.update_bot(@item)
          if response_code == Freshbots::Bot::BOT_UPDATION_SUCCESS_STATUS
            head 204
          else
            raise "error in updating at BOT-SIDE @@response -> #{response}"
          end
        rescue => e
          Rails.logger.error "FRANKBOT-ERROR:   #{e.inspect}, bot_hash -> #{@item.additional_settings[:bot_hash]}, bot_id -> #{@item.id},external_id -> #{@item.external_id},
                              account_id -> #{current_account.id}, portal_id -> #{@item.portal_id}"
          render_base_error(:internal_error, 500)
        end

        def delegator_hash
          @portal = get_portal(params[:portal_id])
          bot = @portal.bot if @portal
          delegator_hash = params.merge(portal: @portal, support_bot: bot)
          delegator_hash
        end

        def constants_class
          'BotConstants'.freeze
        end

        def get_portal(portal_id)
          current_account.portals.where(id: portal_id).first
        end

        def build_object
          account_included = scoper.attribute_names.include?('account_id')
          build_params  = account_included ? { account: current_account } : {}
          build_params  = build_params.merge(
            template_data: {
              header: params['header'],
              theme_colour: params['theme_colour'],
              widget_size: params['widget_size']
            },
            name: params['name'],
            portal_id: params['portal_id']
          )
          @item = scoper.new(build_params)
          @item
        end

        def update_bot_attributes
          @item.name = params['name'] if params['name']
          [:header, :theme_colour, :widget_size].each do |attr|
            @item.template_data[attr] = params[attr] if params[attr]
          end
          @item.last_updated_by = current_user.id
          @avatar = params['avatar']
          if @avatar.present?
            if @avatar['is_default'] == true ||
               (@avatar['is_default'].nil? && @item.additional_settings[:is_default])
              @item.logo.delete if @item.logo
              @item.additional_settings[:is_default] = true
              @item.additional_settings[:avatar_id] = @avatar['avatar_id']
              @item.additional_settings[:default_avatar_url] = @avatar['url']
            else
              update_logo
              @item.additional_settings[:is_default] = false
              @item.additional_settings.delete(:avatar_id)
              @item.additional_settings.delete(:default_avatar_url)
            end
          end
          @item.email_channel = cname_params[:email_channel]
        end

        def update_logo
          logo = current_account.attachments.where(id: @avatar['avatar_id']).first if @avatar['avatar_id'].present?
          @item.logo = logo if logo
        end

        def train_bot
          bot_info = bot_info(@item)
          Rails.logger.info("Enqueueing for overall learning:: #{bot_info}")
          Bot::MlSolutionsTraining.perform_async(bot_id: @item.id)
          Rails.logger.info("Enqueueing for training status check:: #{bot_info}")
          Bot::CheckTrainingStatus.perform_in(2.hours.from_now, bot_id: @item.id, external_id: @item.external_id, portal_id: @item.portal_id)
          @item.training_inprogress!
        rescue => e
          Rails.logger.error "Exception while enqueueing to ml overall learning: #{e.message}, #{bot_info}"
          NewRelic::Agent.notice_error(e)
          raise e
        end

        def handle_category_mapping_failure(error_message)
          @item.category_ids = @old_category_ids if @item.category_ids != @old_category_ids
          Rails.logger.error("BOT :: Category Mapping Failed :: Account id : #{@item.account_id} :: Bot id : #{@item.id} :: #{error_message}")
        end

        def save_bot
          (bot = @item.save) ? bot : render_errors(@item.errors)
        end

        def bot_folder_groups
          @item.solution_category_meta.includes(:primary_category, {solution_folder_meta: :primary_folder}).collect do |c_meta| 
            { 
              :folders       => c_meta.solution_folder_meta,
              :category_name => c_meta.name,
              :category_id   => c_meta.id
            }
          end
        end

        def verify_create_bot_folder
          @validation_klass = BotConstants::SOLUTION_VALIDATION_CLASS
          @delegator_klass  = BotConstants::SOLUTION_DELEGATOR_CLASS
          return unless validate_body_params
          delegator_hash    = params.merge(bot: @item)
          return unless validate_delegator(nil, delegator_hash)
        end

        def transform_response(response)
          response_hash = {}
          response.each do |r|
            response_hash[r[:date]] = r[:vls]
          end
          date_range = Range.new(Date.parse(params[:start_date]), Date.parse(params[:end_date]))
          dates = date_range.to_a.map(&:to_s)
          analytics_response = []
          dates.each do |date|
            analytics_response << { date: date, vls: metrics(response_hash, date) }
          end
          analytics_response
        end

        def metrics(response_hash, date)
          BotConstants::DEFAULT_ANALYTICS_HASH.merge(response_hash[date] || {})
        end

        def check_bot_email_feature
          return if cname_params[:email_channel].blank? || current_account.bot_email_channel_enabled?
          render_request_error(:require_feature, 403, feature: 'bot_email_channel')
        end

        def allow_bot_api?
          cname_params.keys.none? { |x| BotConstants::SKIP_BOT_API.include?(x) }
        end
        
        def scoper
          current_account.bots
        end

    end
  end
end
