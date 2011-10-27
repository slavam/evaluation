class Level < ActiveRecord::Base
  has_many :directions, :class_name => 'Direction', :foreign_key => 'level_id'
end