class Fixation < ActiveRecord::Base
  belongs_to :master, :class_name => 'Worker', :foreign_key => 'master_id' 
  has_many :workers, :class_name => 'Worker', :foreign_key => 'worker_id'
end