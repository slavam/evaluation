class CategoryHistory < Commerce
  belongs_to :division, :class_name => 'BranchOfBank', :foreign_key => 'id_division'
  self.table_name = "FIN.DIVISION_BRANCH_HIST"
end