class Value < ActiveRecord::Base
  belongs_to :period
  belongs_to :factor
  belongs_to :branch_of_bank, :class_name => 'BranchOfBank', :foreign_key => 'division_id'
  belongs_to :action, :class_name => 'Action', :foreign_key => 'type_id'
  belongs_to :worker, :class_name => 'Worker', :foreign_key => 'worker_id'
end