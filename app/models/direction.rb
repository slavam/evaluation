class Direction < ActiveRecord::Base
  has_many :blocks
  has_many :performances
  belongs_to :level, :class_name => 'Level', :foreign_key => 'level_id'
end