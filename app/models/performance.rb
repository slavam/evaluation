class Performance < ActiveRecord::Base
  belongs_to :block, :class_name => 'Block', :foreign_key => 'block_id'
  belongs_to :division, :class_name => 'BranchOfBank', :foreign_key => 'division_id'
  belongs_to :direction, :class_name => 'Direction', :foreign_key => 'direction_id'
  belongs_to :factor, :class_name => 'Factor', :foreign_key => 'factor_id'
  belongs_to :period, :class_name => 'Period', :foreign_key => 'period_id'
  validates :division_id, :presence => true
end