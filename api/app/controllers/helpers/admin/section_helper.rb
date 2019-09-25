module Admin::SectionHelper
  private

    def section_inside_ticket_field?(tf)
      tf.picklist_values.section_picklist_join.exists?
    end

    def clear_on_empty_section
      unless section_inside_ticket_field?(@tf)
        @tf.field_options.delete 'section_present'
        @tf.save
      end
    end
end
