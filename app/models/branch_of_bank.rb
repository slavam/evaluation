class BranchOfBank < Commerce
  has_many :performances
  has_many :category_histories, :class_name => 'CategoryHistory', :foreign_key => 'id_division'
  belongs_to :division_parent, :class_name => 'DivisionParent', :foreign_key => 'parent_id'
  self.table_name = "FIN.DIVISION"
#  set_table_name "FIN.DIVISION"
end