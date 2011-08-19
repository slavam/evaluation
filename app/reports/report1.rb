# encoding: UTF-8
require 'prawn'
#require "C:/Rails/Ruby192/lib/ruby/gems/1.9.1/gems/actionpack-3.0.9/lib/action_view/helpers/number_helper.rb"
class Report1 < Prawn::Document
  def to_pdf(data)
    font "#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf"
    font_size 9
    text "ОЦЕНКА ЭФФЕКТИВНОСТИ ДЕЯТЕЛЬНОСТИ "+data[0].kpi_template.name+' '+data[0].division.name 

    headers = ["Блок","Вес KPI","Показатель","Вес в группе","Доля","План","Факт","Процент выполнения","KPI"]

    move_down 10

    chw = [70, 30, 140, 40, 40, 105, 85, 40, 50]
    bl = y-10
    he = table([headers]) do |t|
      t.column_widths = chw
      t.row_colors = %w[cccccc ffffff]
      t.cell_style = {:padding => 0}
      t.columns(0..8).align = :center
    end      

    number_helper = Object.new.extend(ActionView::Helpers::NumberHelper)
    dat = []
    for d in data do
      dat << [d.block.short_name, d.block.weight*100, d.factor.name, 
#      number_helper.number_with_precision(d.weight_factor.to_f*100, :precision => 2), 
        number_helper.number_to_human(d.weight_factor.to_f*100),
#        d.weight_factor.to_f*100, 
        d.rate, number_helper.number_to_currency(d.plan, :unit => "грн.", :format => "%n %u"), 
        number_helper.number_to_currency(d.fact), 
        number_helper.number_with_precision(d.exec_percent, :precision => 2), d.kpi]      
    end
    
    da = make_table(dat) do |t|
      t.column_widths  = chw 
#      [80, 260, 50, 150, 10, 60, 40, 150]
#      t.cells.style :padding => 2
#      t.cell_style = {:padding => 3}
#      t.columns(0).align = :center
    end  
    table ([[da]])
    
    render
  end
end