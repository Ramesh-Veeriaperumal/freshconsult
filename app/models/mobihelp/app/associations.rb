class Mobihelp::App < ActiveRecord::Base
  has_many :devices, :class_name =>'Mobihelp::Device'
end
