class BranchOfBank < Commerce
  has_many :performances
  belongs_to :division_parent, :class_name => 'DivisionParent', :foreign_key => 'parent_id'
  set_table_name "FIN.DIVISION"
end