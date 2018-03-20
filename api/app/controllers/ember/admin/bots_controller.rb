module Ember
  module Admin
    class BotsController < ApiApplicationController
      include HelperConcern
      include Helpdesk::IrisNotifications
      include ChannelAuthentication

      skip_before_filter :check_privilege, :verify_authenticity_token, only: [:training_completed]
      before_filter :channel_client_authentication, only: [:training_completed]
      before_filter :load_bot_by_external_id, only: [:training_completed]
      around_filter :handle_exception, only: [:training_completed, :mark_completed_status_seen, :enable_on_portal]

      def index
        @bots = {
          onboarded: bot_onboarded?
        }
        load_products
        @bots
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
        portal = @item.portal
        @bot = {
          product: product_hash(portal),
          id: params[:id].to_i,
          external_id: @item.external_id,
          enable_on_portal: @item.enable_in_portal,
          all_categories: categories_list(portal),
          selected_category_ids: @item.solution_category_metum_ids
        }
        training_status = @item.training_status
        @bot.merge!(status: training_status) if training_status
        @bot.merge!(@item.profile)
        @bot
      end

      def update
        return unless validate_query_params(@item)
        return unless validate_delegator(nil, params.merge(support_bot: @item))
        update_bot_attributes
        # Updating bot at Joehukum side
        update_bot if save_bot
      end

      def map_categories
        return unless validate_body_params(@item)
        return unless validate_delegator(@item, params)
        @old_category_ids = @item.solution_category_metum_ids
        begin
          @item.category_ids = params[:category_ids]
          @item.last_updated_by = current_user.id
          ml_response = Ml::Bot.update_ml(@item)
          if ml_response == true
            @item.save!
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

      def training_completed
        return unless validate_state(BotConstants::BOT_STATUS[:training_inprogress])
        @bot.training_completed!
        @bot_user = current_account.users.find_by_id(@bot.last_updated_by)
        categories = @bot.solution_category_meta.includes(:primary_category).map(&:name)
        ::Admin::BotMailer.send_later(:bot_training_completion_email, @bot, @bot_user.email, @bot_user.name, categories)
        notify_to_iris
        head 204
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

      private

        def construct_attributes
          @item.last_updated_by = current_user.id
          product = @portal.product
          @item.product_id = product.id if product
          @item.additional_settings = {}
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

        def validate_state(state)
          render_request_error(:invalid_bot_state, 409) && return unless (@item || @bot).training_status.to_i == state
          true
        end

        def handle_exception
          yield
        rescue => e
          Rails.logger.error "Action name: #{action_name},Message: #{e.message}"
          logger.error e.backtrace.join("\n")
          render_base_error(:internal_error, 500)
        end

        def load_bot_by_external_id
          @bot = current_account.bots.find_by_external_id(params[:id])
          log_and_render_404 unless @bot
        end

        def notify_to_iris
          Rails.logger.info "Pushing bot training completion to iris. Bot id is #{@bot.id}"
          push_data_to_service(IrisNotificationsConfig['api']['collector_path'], iris_payload)
        end

        def payload
          {
            bot_id: @bot.id,
            user_id: @bot_user.id,
            bot_name: @bot.name
          }
        end

        def iris_payload
          {
            payload: payload,
            payload_type: BotConstants::IRIS_NOTIFICATION_TYPE,
            account_id: Account.current.id.to_s
          }
        end

        def get_portal_logo_url(portal)
          logo = portal.logo
          logo_url = logo.content.url if logo.present?
          logo_url
        end

        def product_hash(portal)
          name = portal.main_portal? ? portal.name : portal.product.name
          {
            name: name,
            portal_id: portal.id,
            portal_logo: get_portal_logo_url(portal)
          }
        end

        def load_products
          products_details = []
          portal = current_account.main_portal
          logo_url = get_portal_logo_url(portal)
          bot = portal.bot
          if bot
            bot_name = bot.name
            bot_id = bot.id
          end
          products_details << { name: portal.name, portal_enabled: true, portal_id: portal.id, portal_logo: logo_url, bot_name: bot_name, bot_id: bot_id }
          products = fetch_products
          products.each do |product|
            products_details << product.bot_info
          end
          @bots[:products] = products_details
          @bots
        end

        def delegator_hash
          @portal = get_portal(params[:portal_id])
          bot = @portal.bot if @portal
          delegator_hash = params.merge(portal: @portal, support_bot: bot)
          delegator_hash
        end

        def feature_name
          FeatureConstants::BOT
        end

        def scoper
          current_account.bots
        end

        def constants_class
          'BotConstants'.freeze
        end

        def fetch_products
          current_account.products.preload({ portal: :logo }, :bot)
        end

        def bot_onboarded?
          Account.current.bots.exists?
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
        end

        def update_logo
          logo = current_account.attachments.where(id: @avatar['avatar_id']).first if @avatar['avatar_id'].present?
          @item.logo = logo if logo
        end

        def train_bot
          Bot::MlSolutionsTraining.perform_async(bot_id: @item.id)
          @item.training_inprogress!
        end

        def handle_category_mapping_failure(error_message)
          @item.category_ids = @old_category_ids if @item.solution_category_metum_ids != @old_category_ids
          Rails.logger.error("BOT :: Category Mapping Failed :: Account id : #{@item.account_id} :: Bot id : #{@item.id} :: #{error_message}")
        end

        def categories_list(portal)
          portal.solution_category_meta.preload(:primary_category).customer_categories.map { |c| { id: c.id, label: c.name } }
        end

        def save_bot
          (bot = @item.save) ? bot : render_errors(@item.errors)
        end
    end
  end
end
