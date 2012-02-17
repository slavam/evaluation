# coding: utf-8
require 'spreadsheet'
class DivisionsController < ApplicationController
  def index
    @divisions = Division.order(:id)
  end

  def save_as_xls
    filename = "divisions_odb.xls"
    tempfile = Tempfile.new(filename)
    book = Spreadsheet::Workbook.new
    sheet1 = book.create_worksheet
    sheet1.name = "Отделения ОДБ"
    sheet1.column(0).width = 5
    sheet1.column(2).width = 50
#    sheet1.row(0).height = 18
    sheet1.row(0).push '', '', "Отделения ОДБ"

    format = Spreadsheet::Format.new :color => :black,
                                   :weight => :bold,
                                   :size => 12
    sheet1.row(0).default_format = format
    sheet1.row(3).default_format = format
    sheet1.row(3).push 'ID', 'Код', 'Название'
    divisions = Division.order(:id)
    i = 0
    divisions.each {|d|
      i += 1
      sheet1.row(3+i).push d.id, d.code, d.name
    }
    book.write(tempfile.path)
    send_file tempfile.path, :filename => filename    
  end
end