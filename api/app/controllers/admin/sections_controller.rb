class Admin::SectionsController < ApiApplicationController
  include Admin::TicketFieldHelper

  before_filter :load_object, only: [:destroy]
  before_filter :validate_section, except: [:index, :show]

  def destroy
    ActiveRecord::Base.transaction do
      @item.destroy
      clear_on_empty_section # delete section_present if ticket_field section is empty
      head 204
    end
  end

  private

    def launch_party_name
      FeatureConstants::TICKET_FIELD_REVAMP
    end

    def validate_section
      options = {
        tf: @tf,
        correct_mapping: @correct_value_mapping
      }
      run_validation(options)
    end

    def validation_class
      'Admin::SectionsValidation'.constantize
    end

    def delegation_class
      'Admin::SectionsDelegator'.constantize
    end

    def load_object
      @item = current_account.sections.find_by_id(params[:id])
      log_and_render_404 && return unless @item
      @tf = current_account.ticket_fields_only.find_by_id(params[:ticket_field_id])
      @correct_value_mapping = @item.present? && @tf.present? && (@item.ticket_field_id == @tf.id)
    end
end
