class BranchOfBank < Commerce
  has_many :performances
  set_table_name "FIN.DIVISION"
end