require 'spec_helper'

describe RabbitMqController do

  it "should return the all available exchanges" do
    $rabbitmq_config = YAML::load_file(File.join(Rails.root, 'config', 'rabbitmq.yml'))[Rails.env]
    $rabbitmq_shards = []
    get :index, :secret_key => $rabbitmq_config["secret_key"]
    JSON.parse(response.body)["available_exchanges"].should be_eql(["tickets_0", "notes_0"])
  end

  it "should render error message if the secret key is invalid" do
    get :index, :secret_key => Faker::Lorem.characters(32)
    JSON.parse(response.body)["error"].should be_eql("page not found")
  end

  it "should render error message without the secret key" do
    get :index
    JSON.parse(response.body)["error"].should be_eql("page not found")
  end
end
