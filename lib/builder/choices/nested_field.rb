class Builder::Choices::NestedField < Builder::Choices
  def build_new_choices(choices_params, current_parent = parent)
    if choices_params.present?
      choices_params.each_with_index do |choice_params, index|
        build_new_choice(choice_params, current_parent, index)
      end
    end
  end

  def build_choices(choices_params, choices_list, current_parent = parent)
    choices_params.each_with_index do |choice_params, index|
      pl_picklist_id, pl_value = self.class.fetch_id_and_value(choice_params)
      current_tree = current_choice_present?(pl_picklist_id, choices_list)
      current_tree ? update_current_tree_and_build_sub_choices(current_tree, index, pl_value, choice_params) : build_new_choice(choice_params, current_parent, index)
      mark_choices_for_delete(choices_params, choices_list)
    end
  end

  # Not a public exposed method.
  def build_new_choice(choice_params, current_parent, index)
    current_choice_attributes = transform_api_input(choice_params.merge(position: index + 1).except(:choices))
    sub_tree_choices = choice_params[:choices]
    built_choice = current_parent.construct_choice(current_choice_attributes)
    build_new_choices(sub_tree_choices, built_choice)
  end

  private

    def fetch_id_and_value(choice_params)
      [choice_params.try(:[], :picklist_id), choice_params[:value]]
    end

    def current_choice_present?(pl_picklist_id, choices_list)
      pl_picklist_id.present? && choices_list.detect { |picklist| picklist.picklist_id == pl_picklist_id }
    end

    def update_current_tree_and_build_sub_choices(current_tree, index, pl_value, choice_params)
      current_tree.assign_position_and_value(index + 1, pl_value)
      sub_tree_choices_params = choice_params[:choices]
      build_choices(sub_tree_choices_params,
                    current_tree.sub_picklist_values, current_tree)
    end

    def mark_choices_for_delete(choices_params, choices_list)
      choices_list.each do |choice|
        choice.mark_for_destruction unless current_picklist_present?(choice.picklist_id, choices_params)
      end
    end

    def current_picklist_present?(picklist_id, choices_params)
      choices_params.detect { |choice_params| choice_params[:picklist_id] == picklist_id }
    end
end
