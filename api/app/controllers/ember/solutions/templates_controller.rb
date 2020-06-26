module Ember
  module Solutions
    class TemplatesController < ApiApplicationController
      TEMPLATE_CONSTANT_CLASS = 'Ember::Solutions::TemplateConstants'.freeze
      SINGULAR_RESPONSE_FOR = %w[show create update default].freeze

      include HelperConcern

      skip_before_filter :load_object, only: [:default]
      before_filter :validate_body_params, only: [:create, :update]

      decorate_views

      def default
        @item = default_template
      end

      def create
        return unless validate_delegator(@item, params[cname].slice(:title))

        ActiveRecord::Base.transaction do
          reset_default_template if params[cname][:is_default]
          super
        end
      end

      def update
        return unless validate_delegator(@item, params[cname].slice(:title))

        ActiveRecord::Base.transaction do
          if params[cname][:is_default]
            curr_default_template = default_template
            reset_default_template(curr_default_template) if curr_default_template && curr_default_template.id != @item.id
          end
          super
        end
      end

      private

        def feature_name
          FeatureConstants::SOLUTIONS_TEMPLATES
        end

        def constants_class
          TEMPLATE_CONSTANT_CLASS
        end

        def decorator_options
          [::Solutions::TemplateDecorator, {}]
        end

        def scoper
          current_account.solution_templates
        end

        def load_objects
          super(scoper.order_by_default_latest.preload([:solution_template_mappings]), true)
        end

        def default_template
          scoper.default.first
        end

        def reset_default_template(template = default_template)
          return unless template

          template.is_default = false
          template.save!
        end

        # need to override to use template_url as location_url
        def render_201_with_location(template_name: "#{controller_path.gsub(NAMESPACED_CONTROLLER_REGEX, '')}/#{action_name}", location_url: 'templates_url', item_id: @item.id)
          render template_name, location: safe_send(location_url, item_id), status: :created
        end
    end
  end
end
