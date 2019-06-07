# Class that has contains picklist value base.
class Builder::Choices
  attr_reader :parent

  def initialize(parent)
    @parent = parent
  end

  def build_new_choices(choices_params, current_parent = parent)
    # Inherit for the implementation of choices build.
  end

  private

    def transform_api_input(choice_params)
      { value: choice_params[:value], position: choice_params[:position] }
    end
end
