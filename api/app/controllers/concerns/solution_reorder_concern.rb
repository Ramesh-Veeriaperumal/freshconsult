module SolutionReorderConcern
  extend ActiveSupport::Concern

  included do
    before_filter :validate_reorder_params, :validate_reorder_delegator, :load_reorder_item, only: [:reorder]
    skip_before_filter :load_object, only: [:reorder]

    def reorder
      @reorder_item.insert_at(cname_params[:position]) unless handle_incorrect_positions
      head 204
    rescue => e
      Rails.logger.error("Exception while reordering articles::#{current_account.id}, message::#{e.message}, backtrace::#{e.backtrace.join('\n')}")
      render_errors(message: e.message)
    end

    private

      def validate_reorder_params
        @validation_klass = 'ApiSolutions::ReorderValidation'
        return unless validate_body_params(nil, cname_params.merge(portal_id: params[:portal_id]))
      end

      def validate_reorder_delegator
        # No op function
      end

      def duplicate_position?
        order_details = reorder_scoper.select("min(#{solution_table}.position) as minimum ,max(#{solution_table}.position) as maximum, count(*) as count").first
        order_details.minimum != 1 || order_details.maximum != order_details.count || reorder_scoper.group("#{solution_table}.position").having('count(*) > 1').present?
      end

      def solution_table
        @solution_table ||= reorder_scoper.table_name
      end

      def handle_incorrect_positions
        # if duplicate position exists fix duplicate position using existing order and insert using acts_as_list next time to avoid huge update everytime
        if duplicate_position?
          solution_items = reorder_scoper.all
          old_index = solution_items.index { |item| @reorder_item.id == item.id }
          solution_items.insert(cname_params[:position] - 1, solution_items.delete_at(old_index))
          solution_items.each.with_index(1) do |solution_item, index|
            if solution_item.position != index
              solution_item.position = index
              solution_item.save!
            end
          end
          return true
        end
        false
      end
  end
end
