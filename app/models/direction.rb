class Direction < ActiveRecord::Base
  has_many :blocks
  has_many :performances
#  set_table_name "directions"
#  attr_accessible :direction
end