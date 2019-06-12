class Builder::Choices::CustomDropdown < Builder::Choices
  def build_new_choices(choices_params)
    choices_params.each_with_index do |choice_params, index|
      build_new_choice(choice_params, index) if choice_params[:value].present?
    end
  end

  private

    def build_new_choice(choice_params, index)
      current_choice_attributes = transform_api_input(choice_params.merge(position: index + 1))
      parent.construct_choice(current_choice_attributes)
    end
end
