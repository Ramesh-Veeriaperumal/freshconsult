class ScenarioAutomationDecorator < ApiDecorator
  delegate :id, :name, :description, :action_data, :visible_to_only_me?, to: :record

  def initialize(record, options)
    super(record)
  end

  def to_hash
    {
      id: id,
      name: name,
      description: description,
      actions: action_data.map { |action| action.slice(:name, :value) },
      private: visible_to_only_me?
    }
  end
end
