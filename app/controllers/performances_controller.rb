# coding: utf-8
require 'spreadsheet'
class PerformancesController < ApplicationController
  before_filter :find_direction, :only => [:get_report_division, :get_report_worker, :get_calc_division, :get_calc_worker]
  before_filter :find_period, :only => [:get_report_division, :get_report_worker, :get_calc_division, :get_calc_worker, :kpi_as_xls]
  PLAN_OWNER = 'RPK880508'
  FACT_OWNER = 'SR_BANK'
  FIN_OWNER  = 'FIN'
  PACKAGE = 'vbr_kpi'
  ODB_DBNAME = 'SRBANK3'
  ODB_SP_NAME = {:get_count_term                 => 'tst_count_term',
                 :get_fact_municipal_by_contract => 'tst_count_municipal',
                 :get_fact_depobox               => 'tst_count_depobox',
                 :get_fact_transfer              => 'tst_count_transfer',
                 :get_fact_from_rest             => 'tst_rest_by_ct_type',
                 :get_fact_from_rest_by_program  => 'tst_rest_by_ct_type', 
                 :get_fact_problem_pers          => 'tst_rest_by_ct_type',
                 :get_fact_percent_kb_service_using => 'tst_count_tariff',
                 :get_fact_percent_gsm_service_using => 'tst_count_tariff',
                 :get_fact_open_accounts             => 'tst_count_tariff',
                 :get_fact_enroll_salary             => 'tst_sum_enroll_salary',
#                   :get_fact_count_card_over       => '',
                 :get_fact_card_count            => 'tst_count_card'}
#  @is_data_ready = true
  def index
    @performances = Performance.order(:period_id, :direction_id, :division_id, :block_id, :factor_id)
  end
  
  def show_final_kpi
    @values = Performance.where("block_id = 0 and division_id = ? and direction_id=? and calc_date in (
      select max(calc_date) from performances where block_id = 0 and division_id = ? and direction_id=? 
      group by period_id)",
        params[:division_id], params[:direction_id], params[:division_id], params[:direction_id]).order(:period_id)
  end
  
  def show_final_kpi_for_division
    @values = Performance.where("block_id = 0 and period_id = ? and direction_id=? and calc_date in (
      select max(calc_date) from performances where block_id = 0 and period_id = ? and direction_id=? 
      group by division_id)",
        params[:period_id], params[:direction_id], params[:period_id], params[:direction_id]).order("kpi desc")
  end

  def show_final_kpi_for_direction
    @values = Performance.find_by_sql("select * from performances p 
      join directions d on d.id=p.direction_id and d.level_id = "+params[:level_id]+"
      where block_id = 0 and period_id = "+params[:period_id]+
      " and division_id="+params[:division_id]+" and calc_date in (
      select max(calc_date) from performances where block_id = 0 and period_id = "+
      params[:period_id]+" and division_id="+params[:division_id]+" 
      group by direction_id) order by kpi desc")
  end
  
  def show_values
    p_f = params[:report_params][:period_from] 
    p_t = params[:report_params][:period_to]
    if p_f.to_i > p_t.to_i
      p_f = params[:period_id]
      p_t = params[:period_id]
    end
    if Direction.find(params[:direction_id]).level_id == 4
      @values = Performance.where('division_id=? and direction_id=? and factor_id=?  and employee_id=? and calc_date in(
        select max(calc_date) from performances where division_id=? and direction_id=? and factor_id=? and employee_id=? 
        group by period_id order by period_id)',
        params[:division_id], params[:direction_id], params[:factor_id], params[:worker_id],
        params[:division_id], params[:direction_id], params[:factor_id], params[:worker_id]).order(:period_id)   
    else
      @values = Performance.where('division_id=? and direction_id=? and factor_id=? and period_id between ? and ? and calc_date in(
        select max(calc_date) from performances where division_id=? and direction_id=? and factor_id=? and period_id between ? and ? 
        group by period_id order by period_id)',
        params[:division_id], params[:direction_id], params[:factor_id], p_f, p_t,
        params[:division_id], params[:direction_id], params[:factor_id], p_f, p_t).order(:period_id)
    end  
  end
  
  def show_details
#    odb_connection = OCI8.new("kpi", "MVM55010101", "ora0-i00.vbr.ua:1521/SRBANK")
#    odb_connection = OCI8.new("kpi", "MVM55010101", "ora3-i00:1661/SRBANK")
    odb_connection = OCI8.new("kpi", "MVM55010101", ODB_DBNAME)
#    odb_connection = OCI8.new("kpi", "MVM55010101", nil, :SYSDBA)
    @performance = Performance.find params[:performance_id]  
    if (not @performance.factor.fact_descriptor.nil?) and (@performance.factor.fact_descriptor > '')
      period = Period.find @performance.period_id
      @parameter = ''
      @objects = []
      @total_1 = 0
      @total_2 = 0
      @percent = 0
      odb_division_ids = []
      case @performance.direction.level_id
        when 3
          odb_division_id = get_odb_division_id @performance.division_id
          odb_division_ids << odb_division_id
      end
      function_name = ODB_SP_NAME[@performance.factor.fact_descriptor.to_sym]
      program_names = ''
      Param.where('factor_id=? and action_id=2', @performance.factor_id).each { |p| 
        @parameter += (p.param_description.description+': '+p.value+'; ')
        program_names = p.value if (p.param_description_id == 6 or p.param_description_id == 10)
      }
      case @performance.factor.fact_descriptor
        when 'get_fact_percent_kb_service_using' 
          cursor = get_cursor odb_connection, get_odb_function(function_name, period.end_date, nil, 'O', program_names)
          # r[0] => division_id; r[1] => holder_id; r[2] => contract_id; r[3] => cnt_clb; r[4] => cnt_gsm; r[5] => cnt_active
          get_detailed_objects cursor, @performance.direction.level_id, 6, odb_division_ids, 'SUM', 'SUM'
#          @total_1 = @total_1+@total_2
#          @percent = @total_1>0 ? @total_2*100/@total_1 : 0
              # r[0] => division_id; 
              # r[1] => amount
              # r[2] => amount_cb
              # r[3] => amount_gsm
              # r[4] => amount_active
#              acc = 0
#              cb = 0
#              reg_acc = {}
#              reg_srv = {}
#              facts.clear
#              while r = cursor.fetch()
#                code = get_code_s_by_odb_division_id r[0], direction.id
#                facts[code] = 0 if facts[code].nil?
#                acc = acc +(r[1] ? r[1]:0)
#                cb = cb +(r[2] ? r[2]:0)
#                if not r[1].nil? and (r[1]!=0)
#                  if (not r[2].nil?) 
#                    facts[code] = (r[2] ? r[2]:0)*100/r[1]
#                  end  
#                  if (direction.level_id == 2) and (r[0].to_i != 1) and (r[0].to_i != 322) # 000 & 019
#                    reg_id = get_fd_region_id(r[0])
#                    reg_acc[reg_id] = (reg_acc[reg_id] ? reg_acc[reg_id]:0)+(r[1] ? r[1]:0)
#                    reg_srv[reg_id] = (reg_srv[reg_id] ? reg_srv[reg_id]:0)+(r[2] ? r[2]:0)
#                  end
#                end
#              end
#              fact_of_bank = cb*100/acc if (acc != 0)
#              if direction.level_id == 2
#                reg_acc.each {|id, value|
#                  facts_by_regions[id] = 0
#                  if value != 0
#                    facts_by_regions[id]=reg_srv[id]*100/value
#                  end
#                }
#              end



#            when 'get_fact_percent_gsm_service_using' 
#              program_names = Param.where('factor_id=? and action_id=2 and param_description_id=6', f.id).last.value
#              query = " 
#                declare
#                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
#                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
#                begin "+program_names_to_array(program_names)+
#                  FACT_OWNER+".vbr_kpi.get_count_tariff(TO_DATE('"+ 
#                  period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, :c_cursor);
#                end; " 
#              cursor = get_cursor odb_connect, query
#              # r[0] => division_id
#              # r[1] => amount
#              # r[2] => amount_cb
#              # r[3] => amount_gsm
#              # r[4] => amount_active
#              acc = 0
#              srv = 0
#              reg_acc = {}
#              reg_srv = {}
#              facts.clear
#              while r = cursor.fetch()
#                code = get_code_s_by_odb_division_id r[0], direction.id
#                facts[code] = 0 if facts[code].nil?
#                acc = acc +(r[1] ? r[1]:0)
#                srv = srv +(r[3] ? r[3]:0)
#                if not r[1].nil? and (r[1]!=0)
#                  if (not r[3].nil?) 
#                    facts[code] = (r[3] ? r[3]:0)*100/r[1]
#                  end  
#                  if (direction.level_id == 2) and (r[0].to_i != 1) and (r[0].to_i != 322) # 000 & 019
#                    reg_id = get_fd_region_id(r[0])
#                    reg_acc[reg_id] = (reg_acc[reg_id] ? reg_acc[reg_id]:0)+(r[1] ? r[1]:0)
#                    reg_srv[reg_id] = (reg_srv[reg_id] ? reg_srv[reg_id]:0)+(r[3] ? r[3]:0)
#                  end
#                end
#              end
#              fact_of_bank = srv*100/acc if (acc != 0)
#              if direction.level_id == 2
#                reg_acc.each {|id, value|
#                  facts_by_regions[id] = 0
#                  if value != 0
#                    facts_by_regions[id]=reg_srv[id]*100/value
#                  end
#                }
#              end

        when 'get_fact_from_rest', 'get_fact_from_rest_by_program', 'get_fact_problem_pers'
          cursor = get_cursor odb_connection, get_odb_function(function_name, period.end_date, nil, 'O', program_names)
          # r[0] => division_id; r[1] => user_id; r[2] => object_id; r[3] => ammount_rest; r[4] => ammount_exp
          get_detailed_objects cursor, @performance.direction.level_id, 5, odb_division_ids, 'SUM', 'SUM'
          @total_1 = @total_1+@total_2
          @percent = @total_1>0 ? @total_2*100/@total_1 : 0
        when 'get_fact_transfer'
          cursor = get_cursor odb_connection, get_odb_function(function_name, period.start_date.beginning_of_year, period.end_date, 'O', '')
          get_detailed_objects cursor, @performance.direction.level_id, 4, odb_division_ids, 'NUM', ''
          # r[0] => division_id; r[1] => user_id; r[2] => base_action_id; r[3] => amount
        when 'get_fact_municipal_by_contract'
          cursor = get_cursor odb_connection, get_odb_function(function_name, period.start_date.beginning_of_year, period.end_date, 'U', '')
          get_detailed_objects cursor, @performance.direction.level_id, 5, odb_division_ids, 'SUM', 'SUM'
          # r[0] => division_id; r[1] => user_id; r[2] => contract_id; r[3] => count_total; r[4] => count_flash
#          curr_code = ''
#          municipal_count = 0
#          while r = cursor.fetch()
#            if r[0] == odb_division_id 
#              @objects << {:division_name => division_name, :user_id => r[1], :object_id => r[2], :amount_1 => r[3], :amount_2 => r[4]}
#              @total_1 += r[3]
#              @total_2 += (r[4] ? r[4] : 0)
#            end
#            code = get_code_s_by_odb_division_id r[0], direction.id
#            if code != curr_code
#              if curr_code != ''
#                facts[curr_code] = municipal_count
#                municipal_count = 0
#              end
#              curr_code = code
#            end
#            if (r[1] == 23961) or (r[1] == 0)
#              municipal_count =  municipal_count+r[2]
#            end
#            if r[1] == 24991
#              municipal_count =  municipal_count+ r[3]
#            end                  
#          end   
#          facts[code] = municipal_count         
  #         case when mp.contract_id in
  #         (17608,  -- ПКТС
  #          12205,  -- ЕРЦ
  #          24991,  -- флэш-киоск
  #          10990,  -- пополнения моб. операторов
  #          23961)  -- СДА             
        when 'get_fact_card_count', 'get_count_term', 'get_fact_depobox'
          cursor = get_cursor odb_connection, get_odb_function(function_name, period.end_date, nil, 'O', program_names)
          get_detailed_objects cursor, @performance.direction.level_id, 3, odb_division_ids, 'NUM', ''
          # r[0] => division_id; r[1] => user_id; r[2] => contract_id

      end        
    end
    odb_connection.logoff
  end
  
  def show_contract_parameters
    query = "
      declare
        c_cursor "+FACT_OWNER+"."+PACKAGE+".common_cursor;
        contract_id pls_integer;
        begin_date date;     --дата начала договора
        end_date date;       --дата окончания договора
        close_date date;     --дата закрытия договора
        begin_amount number(38,2);   --начальная сумма договора
        division_id pls_integer;    --id отделения договора
        holder_id  pls_integer;      --id владельца договора
        c_s_name char(5);    --код валюты договора
        customer_code char(100);     --код контрагента
        customer_name char(100);  --наименование контрагента
        status char(15);         --статус договора
        doc_no char(100);          --номер договора
        ct_code char(30); --код типа контракта
        ct_name char(255); --наименование типа контракта 
      begin
        "+FACT_OWNER+"."+PACKAGE+".get_contract_prm("+params[:contract_id]+", :c_cursor);
      end;"
    odb_connection = OCI8.new("kpi", "MVM55010101", ODB_DBNAME)  
    cursor = get_cursor odb_connection, query  
    r = cursor.fetch()
    odb_connection.logoff
#    
    if r
      e = Employee.find_by_sr_user_id(r[5])
      if not e.nil?
        w = Worker.find_by_TABN e.tabn
        if w
          worker = w.LASTNAME+' '+w.FIRSTNAME+' '+w.SONAME
        else 
          worker = r[5]
        end  
      end      
      @contract = {:begin_date => r[0], 
                   :end_date => (r[1] ? r[1]:''), 
                   :close_date => (r[2] ? r[2]:''), 
                   :begin_amount => r[3], 
                   :division => Division.find(r[4]).name,
                   :holder => worker,
                   :c_s_name => r[6],
                   :customer_code => r[7],
                   :customer_name => r[8],
                   :status => r[9],
                   :doc_no => r[10],
                   :ct_code => r[11],
                   :ct_name => r[12]
                  }
    else
      @contract = {:begin_date => '', 
                   :end_date => '', 
                   :close_date => '', 
                   :begin_amount => '', 
                   :division => '',
                   :holder => '',
                   :c_s_name => '',
                   :customer_code => '',
                   :customer_name => '',
                   :status => '',
                   :doc_no => '',
                   :ct_code => '',
                   :ct_name => ''
                  } 
    end  
  end
  
  def get_interval
    @division_id, @direction_id, @factor_id, @worker_id, @period_id = 
      params[:division_id], params[:direction_id], params[:factor_id], params[:worker_id], params[:period_id]
  end
  
  def show_kpi_by_divisions
    @values = Performance.where('period_id=? and direction_id=? and factor_id=? and calc_date in(
      select max(calc_date) from performances where period_id=? and direction_id=? and factor_id=? 
      group by division_id )',params[:period_id], params[:direction_id], params[:factor_id],
      params[:period_id], params[:direction_id], params[:factor_id]).order('kpi desc')   
  end
    
  def get_report_params
  end

  def get_report_division
  end

  def get_report_worker
  end
  
  def get_report_params_2
    direction = Direction.find params[:report_params][:direction_id]
    case direction.level_id 
      when 1 then # whole the bank
        redirect_to :action => :show_report, 
                    :report_params => {:period_id => params[:report_params][:period_id], 
                                       :division_id =>  '999', 
                                       :direction_id => direction.id}
      when 4 then # by worker
        redirect_to :action       => :get_report_worker, 
                    :period_id    => params[:report_params][:period_id],
                    :direction_id => direction.id                             
      else # divisions and regions
        redirect_to :action => :get_report_division, 
                    :direction_id => direction.id, 
                    :period_id => params[:report_params][:period_id]
    end
  end
  
  def calc_kpi
    @direction = Direction.find params[:report_params][:direction_id]
    period = Period.find params[:report_params][:period_id]
    codes = get_codes '999'
#    codes.each {|c|
#      @is_data_ready = true
#      is_collumn_in_table c, period
#      if not @is_data_ready
#        flash_error :data_not_ready
#        redirect_to :action => 'get_calc_params'
#        return
#      end
#    }
#    odb_connection = OCI8.new("kpi", "MVM55010101", "srbank")
#    odb_connection = OCI8.new("kpi", "MVM55010101", "ora0-i00.vbr.ua:1521/SRBANK")
#    odb_connection = OCI8.new("kpi", "MVM55010101", "ora3-i00:1661/SRBANK")
    odb_connection = OCI8.new("kpi", "MVM55010101", ODB_DBNAME)
    case @direction.level_id
      when 4 # all workers MSB
        @workers = Worker.find_by_sql(" select e.id_emp id, e.tabn, e.code_division, 
          e.lastname lastname, e.firstname firstname, e.soname soname, 
          p.division parent from emp2doc e 
          join div2doc d on d.id_division = e.id_division 
          join div2doc p on p.id_division = d.parent_id 
          where e.code_division like '%8000' and e.code_division > '0009999' 
          order by p.code_division")
          
        calc_kpi_for_all_divisions period, @direction, odb_connection
        regions = []
        save_final_kpi period, @direction, regions
        redirect_to :action       => :get_report_worker, 
                    :period_id    => period.id,
                    :direction_id => @direction.id 
      when 2 # all regions 
        regions = BranchOfBank.where("open_date is not null and parent_id = 1 and id != 40").order(:code)
        calc_kpi_for_all_divisions period, @direction, odb_connection
        save_final_kpi period, @direction, regions
        redirect_to :action => 'get_report_division', :direction_id => @direction.id, :period_id => period.id  
      when 3 # all divisions 
        divisions = BranchOfBank.where("open_date is not null").order(:code)
        calc_kpi_for_all_divisions period, @direction, odb_connection
        save_final_kpi period, @direction, divisions
        redirect_to :action => 'get_report_division', :direction_id => @direction.id, :period_id => period.id  
      when 1 # whole bank 
        calc_kpi_for_all_divisions period, @direction, odb_connection
        regions = []
        save_final_kpi period, @direction, regions
        redirect_to :action => :show_report, :report_params => {
                    :period_id => period.id, 
                    :division_id => 999, 
                    :direction_id => @direction.id}
      end
    odb_connection.logoff
  end
    
  def show_report
    if params[:report_params][:worker_id]
      w = Worker.select('code_division, lastname, firstname, soname').
#        find_by_id_emp params[:report_params][:worker_id]
        where('id_emp=?',params[:report_params][:worker_id]).first
#      fullname = w.lastname.to_utf+' '+w.firstname.to_utf+' '+w.soname.to_utf
      code_division = w.code_division[0,3]
      d = BranchOfBank.find_by_code code_division
      fd_division_id = d.id
      worker_id = params[:report_params][:worker_id]
    else
      if params[:division_id]
        fd_division_id = params[:division_id]
      else  
        fd_division_id = params[:report_params][:division_id]
      end
      worker_id = 0
    end
    if params[:period_id]
      period_id = params[:period_id]
    else  
      period_id = params[:report_params][:period_id]
    end
    if params[:direction_id]
      direction_id = params[:direction_id]
    else  
      direction_id = params[:report_params][:direction_id]
    end
    get_kpi period_id, fd_division_id, direction_id, worker_id
    if @performances.size == 0
      flash_error :kpi_not_ready
      redirect_to :action => 'get_report_params'
    end
  end
  
  def report_print
    get_kpi params[:period_id], params[:division_id], params[:direction_id]
    output = 
      Report1.new(:page_size => "A4", :page_layout => :landscape, :margin => 20).to_pdf @performances 

    respond_to do |format|
      format.pdf do
        send_data output, :filename => "report1.pdf", :type => "application/pdf", :format => 'pdf'
      end
    end
  end

  def kpi_as_xls
    number_helper = Object.new.extend(ActionView::Helpers::NumberHelper)
    
    get_kpi params[:period_id], params[:division_id], params[:direction_id], 0
    y_m = @period.start_date.year.to_s+(@period.start_date.month<10 ? '0'+@period.start_date.month.to_s : @period.start_date.month.to_s)
    code = params[:division_id] == '999' ? '999' : BranchOfBank.find(params[:division_id]).code
    filename = "kpi_"+y_m+"_"+code+"_"+params[:direction_id]+".xls"
    tempfile = Tempfile.new(filename)
    book = Spreadsheet::Workbook.new
    sheet1 = book.create_worksheet
    sheet1.name = "KPI"
    sheet1.column(0).width = 12
    sheet1.column(1).width = 7                                     
    sheet1.column(2).width = 30
    sheet1.column(3).width = 12
    sheet1.column(4).width = 6
    sheet1.column(5).width = 14
    sheet1.column(6).width = 14
    sheet1.column(7).width = 13
    sheet1.column(8).width = 8
    format = Spreadsheet::Format.new :horizontal_align => :right
    sheet1.column(4).default_format = format
    sheet1.column(5).default_format = format
    sheet1.column(6).default_format = format
    sheet1.column(7).default_format = format
    sheet1.column(8).default_format = format
    sheet1.row(0).push '', '', "Оценка эффективности деятельности"
    if params[:division_id] == '999'
      sheet1.row(1).push 'Отделение:', 'По всему банку'
    else
      sheet1.row(1).push 'Отделение:', @performances[0].division.name
    end
    
    sheet1.row(2).push 'Шаблон:', @performances[0].direction.name
    sheet1.row(3).push 'Период:', @performances[0].period.description

    format = Spreadsheet::Format.new :color => :black,
                                   :weight => :bold,
                                   :size => 12
    sheet1.row(0).default_format = format
    format = Spreadsheet::Format.new :color => :black,
                                   :weight => :bold,
                                   :size => 10,
                                   :align => :justify
    sheet1.row(5).default_format = format
    sheet1.row(5).height = 24
    sheet1.row(5).push 'Блок', 'Вес блока', 'Показатель', 'Вес показателя', 'Доля', 'План', 'Факт', 'Процент выполнения', 'KPI'
    
    i = 0
    j = 0
    block_name = ''
    factor_total = 0
    average_percent = 0
    kpi_total = 0
    kpi_result = 0
    format = Spreadsheet::Format.new :align => :justify
    sheet1.column(0).default_format = format
    sheet1.column(2).default_format = format
    @performances.each {|p|
      if p.block.categorization
#        category_id = p.division.division_branch_id
        category_id = p.division.category_histories.where("modify_date <= to_date('"+@period.start_date.to_s+"','yyyy-mm-dd')").order(:modify_date).last.id_division_branch
        category_id = 3 if (category_id == 1) or (category_id == 2)
        category_id = 4 if (category_id == 5) or (category_id == 6)
      end  
      if p.block.block_description.name != block_name
        if block_name > ''
          sheet1.row(6+j).set_format(2, (Spreadsheet::Format.new :weight => :bold, :horizontal_align => :left))
          format = Spreadsheet::Format.new :weight => :bold, :horizontal_align => :right
          sheet1.row(6+j).default_format = format
          sheet1.row(6+j).push '', '', 'ИТОГО', '', 
            number_helper.number_with_precision(factor_total, :precision => 3, :separator => '.'), '', '', 
            number_helper.number_with_precision(average_percent/i, :precision => 3, :separator => '.'), 
            number_helper.number_with_precision(kpi_total, :precision => 3, :separator => '.')
          j += 1
        end
        sheet1.row(6+j).push p.block.block_description.short_name, p.block.block_weights.last.weight*100
        block_name = p.block.block_description.name
        factor_total = 0
        average_percent = 0
        i = 0
        kpi_result += kpi_total
        kpi_total = 0.0
        j += 1
      end
      case p.factor.factor_description.unit.name 
        when 'грн.' then 
          plan = number_helper.number_to_currency(p.plan, :unit => "", :format => "%n %u")
          fact = number_helper.number_to_currency(p.fact, :unit => "", :format => "%n %u")
        when '%' then  
          plan = number_helper.number_with_precision(p.plan, :precision => 3, :separator => '.')
          fact = number_helper.number_with_precision(p.fact, :precision => 3, :separator => '.')
        else          
          plan = number_helper.number_with_precision(p.plan, :precision => 0, :separator => '.')
          fact = number_helper.number_with_precision(p.fact, :precision => 0, :separator => '.')
      end
      
      sheet1.row(6+j).push '', '', p.factor.factor_description.short_name+
        (p.factor.factor_description.unit_id != 4 ? ' ('+p.factor.factor_description.unit.name+')':''),
        (p.block.categorization ? p.factor.factor_weights.where("division_category_id=?",category_id).last.weight*100 : p.factor.factor_weights.last.weight*100),
        number_helper.number_with_precision(p.rate, :precision => 3, :separator => '.'), 
        plan, fact, 
        number_helper.number_with_precision(p.exec_percent, :precision => 3, :separator => '.'), 
        number_helper.number_with_precision(p.kpi, :precision => 3, :separator => '.')
      j += 1
      i += 1
      factor_total+=p.rate
      average_percent += p.exec_percent
      kpi_total += p.kpi
    }
    format = Spreadsheet::Format.new :weight => :bold, :horizontal_align => :right
    sheet1.row(6+j).set_format(2, (Spreadsheet::Format.new :weight => :bold, :horizontal_align => :left))
    sheet1.row(6+j).default_format = format
    sheet1.row(6+j).push '', '', 'ИТОГО', '', 
      number_helper.number_with_precision(factor_total, :precision => 3, :separator => '.'), '', '', 
      number_helper.number_with_precision(average_percent/i, :precision => 3, :separator => '.'), 
      number_helper.number_with_precision(kpi_total, :precision => 3, :separator => '.')
    sheet1.row(6+j+1).set_format(0, (Spreadsheet::Format.new :weight => :bold, :horizontal_align => :left))  
    sheet1.row(6+j+1).default_format = format
    sheet1.row(6+j+1).push 'ИТОГО', '', '', '', '', '', '', '', 
    number_helper.number_with_precision(kpi_result+kpi_total, :precision => 3, :separator => '.')
    book.write(tempfile.path)
    File.chmod(0744, tempfile.path)  
    send_file tempfile.path, :type => "application/vnd.ms-excel", :filename => filename
    tempfile.close
    tempfile.unlink
#    File.delete(tempfile.path)
  end
  
  private

  def get_problem_percent factor_id, argument
    pr = ProblemRate.select(:result_value).
      where('? between begin_value and stop_value and factor_id=?', argument, factor_id).
      order(:start_date).last
    return pr ? pr.result_value : 0  
  end
  
#  def get_plans start_date, end_date, codes
#    res = ''
#    codes.each {|c|
#      for i in start_date.month..end_date.month
#        res = res+'r'+c+'.plan_'+i.to_s+'+'
#      end
#    }
#    return res[0, res.length-1]
#  end

#  def get_fd_ids division_id
#    fd_ids = []
#    if division_id == '999' #'1' # whole the bank
#      BranchOfBank.select(:id).where("open_date is not null").collect { 
#        |d| fd_ids << d.id
#      }  
#    else
#      division = BranchOfBank.find division_id
#      if division.parent_id == 1 and not division.open_date.nil?
#        BranchOfBank.select(:id).where("parent_id=? and open_date is not null", division_id).collect {|d| fd_ids << d.id}
#      else
#        fd_ids << division.id
#      end
#    end
#    return fd_ids
#  end

  def get_codes division_id
    codes = []
    if division_id == '999' # whole the bank
      BranchOfBank.select(:code).where("open_date is not null").collect { 
        |d| codes << d.code
      }  
    else
      division = BranchOfBank.find division_id
      if division.parent_id == 1 and not division.open_date.nil?
        BranchOfBank.select(:code).where("parent_id=? and open_date is not null", division_id).collect {|d| codes << d.code}
      else
        codes << division.code
      end
    end
    return codes
  end
  
  def get_plan_from_values_by_worker period_id, worker_id, factor_id
    return Value.select('factor_value as plan').
      where("period_id=? and worker_id=? and factor_id=? and type_id=1", period_id, worker_id, factor_id).
      order(:create_date).last.plan  
  end
  
  def collect_plan_from_values_by_workers period_id, division_id, collect_factor_id
    return Value.select('sum(factor_value) as plan').
      where("period_id=? and division_id=? and factor_id=? and type_id=1 and create_date in
      (select max(create_date) from values where period_id=? and division_id=? and factor_id =? and type_id=1 group by division_id)", 
      period_id, division_id, collect_factor_id, period_id, division_id, collect_factor_id).plan  
  end
 
  def make_fields_list start_date, end_date
    s_m = start_date.month
    e_m = end_date.month
    res = 'sum('
    for i in (s_m..e_m)
      res = res + 'v.mes'+i.to_s+'+' 
    end
    return res[0, res.length-1]+')'
  end
     
  def get_fact_from_values period_id, division_id, factor_id
    vf = Value.select('factor_value as fact').
      where("period_id=? and division_id=? and factor_id=? and type_id=2", period_id, division_id, factor_id).order(:create_date).last
    if not vf.nil?
      return vf.fact
    else
      f = Factor.find factor_id
      b_d_id = f.block.block_description_id
      if (b_d_id == 2) or (b_d_id == 3)
        return 100
      else
        if f.factor_description_id == 5 # "% проблемности"
          return -1
        else
          return 0
        end  
      end
    end  
  end

=begin            

>>Выполнение плана по количеству открытых счетов на отчетную дату
открытые текущие счета ИБ - IST
в т.ч. ISTG - гривна
       ISTP - пенсионные счета
       IST$ - валютные счета

открытые текущие счета КБ - KST
в т.ч. KSTG - гривна
       KST$ - валютные счета
       KZP  - зарплатные проекты
       KCOLL - договора инкассации

открытые текущие счета бизнеса Z - ZKST
в т.ч. ZKSTG - гривна
       ZKST$ - валютные счета
       ZKZP  - зарплатные проекты 
=end  

#  def get_joins_for_result codes
#    res = ''
#    codes.each {|c|
#      res = res+"join "+PLAN_OWNER+".REZULT_"+c+" r"+c+" on d.id = r"+c+".id_directory "
#    }              
#    return res
#  end

  def program_names_to_array string_program_names
    names = string_program_names.split(',')
    i = 1
    res = ''
    names.each {|n|
      res = res + "m_macro_table.extend;
        m_macro_table("+i.to_s+") := "+FACT_OWNER+".T_STR_ROW('"+n+"'); "
      i += 1  
    }
    return res                     
  end
  
  def save_kpi period_id, division_id, direction_id, block_id, factor_id, worker_id, fullname, 
    rate, plan, fact, percent, kpi 
    @performance = Performance.new
    @performance.period_id = period_id
    @performance.division_id = division_id
    @performance.direction_id = direction_id
    @performance.block_id = block_id
    @performance.factor_id = factor_id
    @performance.employee_id = worker_id
    @performance.fullname = fullname
    @performance.rate = rate
    @performance.plan = plan
    @performance.fact = fact
    @performance.exec_percent = percent
    @performance.kpi = kpi
    @performance.calc_date = Time.now
    @performance.save
  end
  
  def get_kpi period_id, division_id, direction_id, worker_id
    if not worker_id.nil? and worker_id.to_i>0
      @performances = Performance.where("period_id=? and division_id=? and direction_id=? and employee_id=? and calc_date in (
        select max(calc_date) from performances where period_id=? and division_id=? and direction_id=? and employee_id=?
        group by factor_id order by factor_id)",
        period_id, division_id, direction_id, worker_id, period_id, division_id, direction_id, worker_id).order(:block_id, :factor_id)
    else
      @performances = []
      Performance.where("factor_id > 0 and period_id=? and division_id=? and direction_id=? and calc_date in (
      select max(calc_date) from performances where factor_id > 0 and period_id=? and division_id=? and direction_id=? 
      group by factor_id order by factor_id)",
      period_id, division_id, direction_id, period_id, division_id, direction_id).order(:block_id, :factor_id).each {|p| 
        @performances << p if p.factor.factor_weights.last.weight > 0.00001 
      }
    end  
  end
   
  def get_odb_division_id fd_division_id
    code = BranchOfBank.find(fd_division_id).code.to_i
    return Division.find_by_code(code == 2 ? 1 : code).id
  end
  
  def find_direction
    @direction = Direction.find params[:direction_id]    
  end
  
  def find_period
    @period = Period.find params[:period_id]    
  end

  def get_code_s_by_odb_division_id odb_division_id, direction_id
    if odb_division_id == 1
      if direction_id == 32 # Руководители отделений ПАТ "ВБР" (ИБ)
        return '002'
      else
        return '000'
      end
    else
      c = Division.find(odb_division_id).code.to_i
      return c > 9 ? '0'+c.to_s : '00'+c.to_s 
    end
  end
  
  def calc_kpi_for_all_divisions period, direction, odb_connect
    code_by_id = {}
    parents = {}
    bb = BranchOfBank.where('open_date is not null').order(:code)
    bb.each {|b| 
      code_by_id[b.id] = b.code
      if (b.id == 1) or (b.id == 40) #  000 or 019
        parents[b.code] = 0
      else
        if b.parent_id == 1
          parents[b.code] = b.id
        else
          parents[b.code] = b.parent_id
        end
      end  
    }
    plans = {}
    facts = {}
    facts_by_worker = {}
    plans_by_worker = {}
    facts_by_regions = {}
    for b in direction.blocks do
      for f in b.factors do
        facts_by_worker.clear
        plans_by_worker.clear
        facts_by_regions.clear
        fact_of_bank = 0
        if f.factor_weights.last.weight > 0.00001
          function_name = ODB_SP_NAME[f.fact_descriptor.to_sym]
          plans.clear
          facts.clear
          code_by_id.each_value{|code| plans[code] = 0 }
          if (not f.plan_descriptor.nil?) and f.plan_descriptor > ''
            case f.plan_descriptor
              when 'get_plan_from_values'
                Value.where("period_id=? and factor_id=? and type_id=1 and create_date in
                  (select max(create_date) from values where period_id=? and factor_id =? and type_id=1 group by division_id)", 
                  period.id, f.id, period.id, f.id).order(:division_id).each{|v|
                    plans[code_by_id[v.division_id]] = v.factor_value.to_f
                  }  
              when 'get_plan_from_values_by_worker'
                values = Value.select('worker_id, sum(factor_value) as plan').
                  where("period_id=? and factor_id=? and type_id=1",period.id, f.id).group(:worker_id).order(:worker_id)
                values.each {|v| plans_by_worker[v.worker_id.to_i] = v.plan }
              when 'get_plan_balances' # plan & fact
                query ="    
                  select div.code,sum(dfp.base_amount) fact,sum(dfp.plan) plan
                    from "+FIN_OWNER+".credit_deposit_value dfp,
                      (SELECT d.id, d.code FROM "+FIN_OWNER+".division d where d.fact=1) div
                    where
                      dfp.periods_id in (select p.id from "+FIN_OWNER+".periods p where p.type_period='M'
                        and p.date_from between TO_DATE('"+period.start_date.to_s+"','yyyy-mm-dd')
                        and TO_DATE('"+period.end_date.to_s+"','yyyy-mm-dd'))
                      and dfp.credit_deposit_factor_id = 24
                      and dfp.division_id = div.id
                      group by div.code"                
                facts.clear
                PlanDictionary.find_by_sql(query).each {|rest|
                  plans[rest.code] = rest.plan
                  facts[rest.code] = rest.fact
                }
              when 'get_plan_from_bp_new_by_begin_year'
                article = Param.where('factor_id=? and action_id=1 and param_description_id=4', f.id).last.value
                code_by_id.each_value {|c|
                  query = "
                    select "+make_fields_list(period.start_date.beginning_of_year, period.end_date)+
                      " plan from "+PLAN_OWNER+".bp_"+c+" v where id_sprav in
                      (select id from "+PLAN_OWNER+".bp_sprav s where s.namepp in ("+article+"))"                
                  p = PlanDictionary.find_by_sql(query).last
                  plans[c] = p.plan
                }
# Need save this code                
#                query ="    
#                  select d.code, "+make_fields_list(period.start_date.beginning_of_year, period.end_date)+" plan from
#                     "+FIN_OWNER+".factor f,
#                     "+FIN_OWNER+".bud_value v,
#                     "+FIN_OWNER+".bud_prefix p,
#                     "+FIN_OWNER+".division d
#                   where f.id = v.factor_id(+)
#                     and v.bud_prefix_id = p.id
#                     and p.id = 4 
#                     and f.code in ("+article+")
#                     and v.division_id = d.id
#                     and d.code in ("+code_by_id.values.join(',')+") group by d.code"
#                plan_by_code = PlanDictionary.find_by_sql(query)
#                plan_by_code.each {|p|
#                  plans[p.code] = p.plan
#                }

              when 'get_plan_fact_over_average' # plan & fact
                business = Param.where('factor_id=? and action_id=1 and param_description_id=11', f.id).last.value
                query = "
                  select div.code, abs(sum(dfp.base_amount)) as fact, sum(dfp.plan) plan
                  from "+FIN_OWNER+".credit_deposit_value dfp, "+FIN_OWNER+".periods p,
                    (SELECT ID FROM "+FIN_OWNER+".credit_deposit_factor t
                      CONNECT BY PRIOR t.ID = t.PARENT_ID START WITH id =25) tree,
                    (select id, code from "+FIN_OWNER+".division where open_date is not null) div
                  where
                    dfp.sr_busines_id like (select id from FIN.sr_busines where code = '"+business+"')
                    and dfp.division_id = div.id
                    and p.id = dfp.periods_id
                    and dfp.credit_deposit_factor_id =tree.id
                    and dfp.periods_id in (select id from fin.periods p 
                      where p.type_period='M' and p.date_from = TO_DATE('"+period.start_date.to_s+"','yyyy-mm-dd'))
                  group by div.code"
                overs = PlanDictionary.find_by_sql(query)
                facts.clear
                overs.each {|o|
                  plans[o.code] = o.plan
                  facts[o.code] = o.fact
                }
              when 'get_plan_const'  
                plan = Param.where('factor_id=? and action_id=1 and param_description_id=8', f.id).last.value.to_i
                plans.clear
                code_by_id.each_value {|c| plans[c] = plan }
              when 'get_plan_from_bp_new'
                article = Param.where('factor_id=? and action_id=1 and param_description_id=4', f.id).last.value
                code_by_id.each_value {|c|
                  query = "
                    select sum(mes"+period.end_date.month.to_s+") plan from "+PLAN_OWNER+".bp_"+c+" where id_sprav in
                      (select id from "+PLAN_OWNER+".bp_sprav s where s.namepp in ("+article+"))"                
# Need save this code
#                  query = "
#                    select sum(v.mes"+period.end_date.month.to_s+") plan from
#                      "+FIN_OWNER+".factor f, 
#                      "+FIN_OWNER+".bud_value v,
#                      "+FIN_OWNER+".bud_prefix p,
#                      "+FIN_OWNER+".division d
#                      where f.id = v.factor_id(+)
#                      and v.bud_prefix_id = p.id
#                      and p.id = 4 /*с учетом всех корректировок*/
#                      and f.code in ("+article+")
#                      and v.division_id = d.id
#                      and d.code in ("+c+")"
                  p = PlanDictionary.find_by_sql(query).last
                  plans[c] = p.plan
                }
              when 'get_plan_fin_res'
                article = Param.where('factor_id=? and action_id=1 and param_description_id=5', f.id).last.value
                business = Param.where('factor_id=? and action_id=1 and param_description_id=11', f.id).last.value
                if business == '%'
                  s = " "
                else  
                  s = " and b.code = '"+business+"' "
                end
                query = "
                  select 
                    sum(fvp.value) plan,  
                    d.code     --Код отделения
                  from
                    "+FIN_OWNER+".finres_directory fd,
                    "+FIN_OWNER+".finres_value_plan fvp,
                    "+FIN_OWNER+".division d,
                    "+FIN_OWNER+".sr_busines b,
                    "+FIN_OWNER+".periods p
                  where fvp.finres_directory_id = fd.id
                    and fvp.division_id = d.id and d.open_date is not null
                    and fvp.sr_busines_id = b.id
                    and fvp.period_id = p.id
                    and fd.code = "+article+" "+s+"
                    and p.type_period = 'M'
                    and p.date_from <= to_date('"+period.end_date.to_s+"','yyyy-mm-dd')
                    and p.date_to >= to_date('"+period.start_date.beginning_of_year.to_s+"','yyyy-mm-dd')
                  group by d.code order by d.code"
                PlanDictionary.find_by_sql(query).each {|fr| plans[fr.code] = fr.plan }
              when 'get_plan_fin_res_by_interval'  
                article = Param.where('factor_id=? and action_id=1 and param_description_id=5', f.id).last.value
                business = Param.where('factor_id=? and action_id=1 and param_description_id=11', f.id).last.value
                query = "
                  select fpv.division_id, sum(fpv.value) as plan
                  from "+FIN_OWNER+".finres_value_plan fpv
                  join "+FIN_OWNER+".sr_busines b on b.id = fpv.sr_busines_id and b.code = '"+business+"'
                  where fpv.period_id in (select p.id from "+FIN_OWNER+".periods p
                    where p.date_to >= to_date('"+period.start_date.to_s+"','yyyy-mm-dd')
                    and p.date_from <= to_date('"+period.end_date.to_s+"','yyyy-mm-dd') and p.type_period='M')
                    and fpv.finres_directory_id in (
                    select id from "+FIN_OWNER+".finres_directory where code = "+article+")
                  group by fpv.division_id               
                "
                PlanDictionary.find_by_sql(query).each {|fr| plans[code_by_id[fr.division_id]] = fr.plan }
            end
          end
          if (not f.fact_descriptor.nil?) and f.fact_descriptor > ''
            p = Param.where('factor_id=? and action_id=2 and param_description_id=6', f.id).last
            program_names = p ? p.value : '' 
            if f.fact_descriptor == 'get_fact_from_values'
              case direction.level_id
                when 1
                  fact_of_bank = 0
                  fact_of_bank = get_fact_from_values period.id, 999, f.id
                  if (f.block.block_description_id == 2) or (f.block.block_description_id == 3)   # задачи, стандарт
                    fact_of_bank = 100 if fact_of_bank.nil? or (fact_of_bank == 0)
                  end  
                when 2
                  parents.each_value {|id|
                    facts_by_regions[id] = get_fact_from_values period.id, id, f.id
                    if (f.block.block_description_id == 2) or (f.block.block_description_id == 3)   # задачи, стандарт
                      facts_by_regions[id] = 100 if facts_by_regions[id].nil? or (facts_by_regions[id] == 0)   
                    end
                  }
                when 3
                  facts.clear
                  if (f.block.block_description_id == 2) or (f.block.block_description_id == 3)   # задачи, стандарт
                    code_by_id.each_value{|code| facts[code] = 100 }
                  else
                    if f.factor_description_id == 5 # "% проблемности"
                      code_by_id.each_value{|code| facts[code] = -1 }
                    end 
                    Value.where("period_id=? and factor_id=? and type_id=2 and create_date in
                      (select max(create_date) from values where period_id=? and factor_id =? and type_id=2 group by division_id)", 
                      period.id, f.id, period.id, f.id).order(:division_id).each {|v|
                        facts[code_by_id[v.division_id]] = v.factor_value.to_f
                      }
                  end
                when 4
                  values = Value.select('worker_id, sum(factor_value) as fact').
                    where("period_id=? and factor_id=? and type_id=2",period.id, f.id).group(:worker_id).order(:worker_id)
                  facts_by_worker.clear
                  if (f.block.block_description_id == 2) or (f.block.block_description_id == 3)   # задачи, стандарт
                    tabn_by_id = {}
                    @workers.each {|w|
                      tabn_by_id[w.id]=w.tabn.to_i
                      facts_by_worker[w.tabn.to_i] = 100
                    }
                  end
                  values.each {|v| facts_by_worker[tabn_by_id[v.worker_id.to_i]] = v.fact }
              end
            end
            if f.fact_descriptor == 'get_fact_problem_percent_by_worker'  
              query = "
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                begin "+program_names_to_array(program_names)+
                  FACT_OWNER+".vbr_kpi.get_rest_by_ct_type(TO_DATE('"+ 
                  period.end_date.to_s+"','yyyy-mm-dd'), 
                  'CREDIT_DOCUMENT', 'T', m_macro_table, :c_cursor);
                end;"
              cursor = get_cursor odb_connect, query
              # r[0] => division_id; r[1] => user_id; r[2] => ammount_rest; r[3] => ammount_exp
              facts_by_worker.clear
              while r = cursor.fetch()
                e = Employee.find_by_sr_user_id(r[1])
                if not e.nil?
                  pers_number = e.tabn.to_i
                  if (r[3]+r[2])!=0
                    facts_by_worker[pers_number] = r[3]*100/(r[3]+r[2])
                  else  
                    facts_by_worker[pers_number] = 0
                  end  
                end  
              end
            end
            if f.fact_descriptor == 'get_fact_rest_by_worker'  
              query = "
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                begin "+program_names_to_array(program_names)+
                  FACT_OWNER+".vbr_kpi.get_count_credit(TO_DATE('"+ 
                  period.end_date.to_s+"','yyyy-mm-dd'), 
                  'T', m_macro_table, :c_cursor);
                end;"
              cursor = get_cursor odb_connect, query
              # r[0] => division_id; r[1] => user_id; r[2] => cnt; r[3] => amount
              facts_by_worker.clear
              while r = cursor.fetch()
                e = Employee.find_by_sr_user_id(r[1])
                if not e.nil?
                  pers_number = e.tabn.to_i
                  facts_by_worker[pers_number] = r[3]
                end  
              end
              query = "
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                begin "+program_names_to_array(program_names)+
                  FACT_OWNER+".vbr_kpi.get_count_credit(TO_DATE('"+ 
                  period.start_date.yesterday.to_s+"','yyyy-mm-dd'), 
                  'T', m_macro_table, :c_cursor);
                end;"
              cursor = get_cursor odb_connect, query
              while r = cursor.fetch()
                e = Employee.find_by_sr_user_id(r[1])
                if not e.nil?
                  pers_number = e.tabn.to_i
                  facts_by_worker[pers_number] = facts_by_worker[pers_number]-r[3]
                end  
              end
            end
            if f.fact_descriptor == 'get_fact_problem_pers' 
              cursor = get_cursor odb_connect, get_odb_function(function_name, period.end_date, nil, 'D', program_names)
#              query = "
#                declare
#                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
#                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
#                begin "+program_names_to_array(program_names)+
#                  FACT_OWNER+".vbr_kpi.get_rest_by_ct_type(TO_DATE('"+ 
#                  period.end_date.to_s+"','yyyy-mm-dd'), 
#                  'CREDIT_DOCUMENT', 'F', m_macro_table, :c_cursor);
#                end;"
#              cursor = get_cursor odb_connect, query
              # r[0] => division_id; r[1] => ammount_rest; r[2] => ammount_exp
              facts.clear
              code_by_id.each_value {|code| facts[code] = -1}
              business = Param.where('factor_id=? and action_id=2 and param_description_id=11', f.id).last.value
              query = "
                select div.code, abs(sum(dfp.base_amount)) as fact
                from "+FIN_OWNER+".credit_deposit_value dfp, "+FIN_OWNER+".periods p,
                  (SELECT ID FROM "+FIN_OWNER+".credit_deposit_factor t
                    CONNECT BY PRIOR t.ID = t.PARENT_ID START WITH id =25) tree,
                  (select id, code from "+FIN_OWNER+".division where open_date is not null) div
                where
                  dfp.sr_busines_id like (select id from FIN.sr_busines where code = '"+business+"')
                  and dfp.division_id = div.id
                  and p.id = dfp.periods_id
                  and dfp.credit_deposit_factor_id =tree.id
                  and dfp.periods_id in (select id from fin.periods p 
                    where p.type_period='M' and p.date_from = TO_DATE('"+period.start_date.to_s+"','yyyy-mm-dd'))
                group by div.code"
                
              PlanDictionary.find_by_sql(query).each {|o| facts[o.code] = 0 if o.fact.to_f > 0.0}

              exp = 0
              rest = 0
              reg_exp = {}
              reg_rest = {}
              while r = cursor.fetch()
                exp = exp+r[2]
                rest = rest+r[1]+r[2]
                code = get_code_s_by_odb_division_id r[0], direction.id
                code = '002' if (code == '000') and (f.id == 235 or f.id == 219 or f.id == 248) # problem with codes 000 and 002
                if (direction.level_id == 2) and (r[0].to_i != 1) and (r[0].to_i != 322) # 000 & 019
                  reg_id = get_fd_region_id(r[0])
                  reg_exp[reg_id] = reg_exp[reg_id] ? reg_exp[reg_id]:0+r[2]
                  reg_rest[reg_id] = reg_rest[reg_id] ? reg_rest[reg_id]:0+r[2]+r[1]
                end
                facts[code] = r[2]*100/(r[1]+r[2]) if (r[1]+r[2])!=0
              end
                  
              fact_of_bank = exp*100/rest if (rest != 0)
              if direction.level_id == 2
                reg_rest.each {|id, value|
                  facts_by_regions[id] = 0
                  facts_by_regions[id]=reg_exp[id]*100/value if (value != 0)
                }
              end
            end
            if (f.fact_descriptor == 'get_fact_from_rest_by_program') or (f.fact_descriptor == 'get_fact_from_rest')
              cursor = get_cursor odb_connect, get_odb_function('tst_rest_by_ct_type', period.end_date, nil, 'D', program_names)
              # r[0] => division_id; r[1] => ammount_rest; r[2] => ammount_exp
              facts.clear
              while r = cursor.fetch()
                code = get_code_s_by_odb_division_id r[0], direction.id
                code = '002' if (code == '000') and (f.id == 234) and (program_names == 'KKG') # Гарантии
                facts[code] = r[1]+r[2]
              end
            end
            if f.fact_descriptor == 'get_fact_credit_value' 
              business = Param.where('factor_id=? and action_id=2 and param_description_id=11', f.id).last.value
              query = "             
                select d.code, sum(dfp.base_amount) fact
                  from "+FIN_OWNER+".credit_deposit_value dfp, "+FIN_OWNER+".division d
                  where dfp.periods_id=(select id from "+FIN_OWNER+
                    ".periods where date_from = TO_DATE('"+period.end_date.to_s+"','yyyy-mm-dd'))
                    and dfp.credit_deposit_factor_id = (
                      select id from "+FIN_OWNER+".credit_deposit_factor
                        where parent_id = 1 and sr_busines_id =
                          (select id from "+FIN_OWNER+".sr_busines where code = '"+business+"'))                    
                    and dfp.division_id = d.id 
                    and d.open_date is not null
                    group by d.code"
              facts.clear
              PlanDictionary.find_by_sql(query).each {|credit|
                facts[credit.code] = credit.fact
              }
              
              if business == 'K' # subtract factoring
                cursor = get_cursor odb_connect, get_odb_function('tst_rest_by_ct_type', period.end_date, nil, 'D', '202-001-01')
                # r[0] => division_id; r[1] => ammount_rest; r[2] => ammount_exp
                while r = cursor.fetch()
                  code = get_code_s_by_odb_division_id r[0], direction.id
                  facts[code] = (facts[code] ? facts[code] : 0) - (r[1]+r[2])
                end
              end
            end
            if f.fact_descriptor == 'get_fact_transfer'
              cursor = get_cursor odb_connect, 
                get_odb_function(function_name, period.start_date.beginning_of_year, period.end_date, 'D', '')
              # r[0] => division_id; r[1] => amount
              facts.clear
              while r = cursor.fetch()
                code = get_code_s_by_odb_division_id r[0], direction.id
                facts[code] = r[1]
              end
            end
            if f.fact_descriptor == 'get_fact_depobox' 
              query = " 
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                begin "+program_names_to_array(program_names)+
                  FACT_OWNER+".vbr_kpi.get_count_depobox(TO_DATE('"+ 
                  period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, :c_cursor); 
                end; "     
              cursor = get_cursor odb_connect, query

              # r[0] => division_id; r[1] => amount
              facts.clear
              while r = cursor.fetch()
                code = get_code_s_by_odb_division_id r[0], direction.id
                facts[code] = r[1]
              end
            end
            if f.fact_descriptor == 'get_fact_fin_res'
              article = Param.where('factor_id=? and action_id=2 and param_description_id=5', f.id).last.value
              business = Param.where('factor_id=? and action_id=2 and param_description_id=11', f.id).last.value
              if business == '%'
                s = " "
              else  
                s = " and b.code = '"+business+"' "
              end
              query = "
                select
                  -sum(fv.value) fact,
                  d.code     --Код отделения
                from
                  "+FIN_OWNER+".finres_directory fd,
                  "+FIN_OWNER+".finres_value fv,
                  "+FIN_OWNER+".division d,
                  "+FIN_OWNER+".sr_busines b,
                  "+FIN_OWNER+".periods p
              where fv.finres_directory_id = fd.id
                 and fv.division_id = d.id
                 and fv.sr_busines_id = b.id
                 and fv.period_id = p.id
                 and p.type_period = 'D'
                 and fd.code = "+article+"
                 and d.open_date is not null "+s+"
                 and p.date_from = to_date('"+period.end_date.to_s+"','yyyy-mm-dd')
                 group by d.code  order by d.code"
              facts.clear
              PlanDictionary.find_by_sql(query).each {|fr| facts[fr.code] = fr.fact }
            end
            if f.fact_descriptor == 'get_fact_municipal_by_contract'
              cursor = get_cursor odb_connect, get_odb_function(function_name, 
                period.start_date.beginning_of_year, period.end_date, 'D', '')
              # r[0] => division_id; r[1] => contract_id; r[2] => count_payment; r[3] => count_payment2
              facts.clear
              curr_code = ''
              municipal_count = 0
              while r = cursor.fetch()
                code = get_code_s_by_odb_division_id r[0], direction.id
                if code != curr_code
                  if curr_code != ''
                    facts[curr_code] = 0 if facts[curr_code] == nil
                    facts[curr_code] += municipal_count
                    municipal_count = 0
                  end
                  curr_code = code
                end
                if (r[1] == 23961) or (r[1] == 0)
                  municipal_count =  municipal_count+r[2]
                end
                if r[1] == 24991
                  municipal_count =  municipal_count+ r[3]
                end                  
              end   
              facts[code] = municipal_count         
      #         (17608,  -- ПКТС
      #          12205,  -- ЕРЦ
      #          24991,  -- флэш-киоск
      #          10990,  -- пополнения моб. операторов
      #          23961)  -- СДА             
            end
            if f.fact_descriptor == 'get_fact_current_accounts' # plan & fact
              businnes_code = Param.where('factor_id=? and action_id=2 and param_description_id=11', f.id).last.value
              query = "
                select div.code, abs(sum(dfp.base_amount)) as fact, sum(dfp.plan) as plan
                  from "+FIN_OWNER+".credit_deposit_value dfp,
                    (SELECT ID FROM "+FIN_OWNER+".credit_deposit_factor t
                      CONNECT BY PRIOR t.ID = t.PARENT_ID START WITH id =20) tree, 
                    (SELECT d.id, d.name, d.code FROM "+FIN_OWNER+".division d where d.fact=1) div
                  where dfp.division_id = div.id and
                    dfp.sr_busines_id like (select id from "+FIN_OWNER+".sr_busines where code = '"+businnes_code+"')
                    and dfp.credit_deposit_factor_id =tree.id
                    and dfp.periods_id in (select id from fin.periods p 
                      where p.type_period='M' and p.date_from = TO_DATE('"+period.start_date.to_s+"','yyyy-mm-dd'))
                  group by div.code order by div.code"
              facts.clear
              PlanDictionary.find_by_sql(query).each {|rest|
                plans[rest.code] = rest.plan
                facts[rest.code] = rest.fact
              }
            end
            if f.fact_descriptor == 'get_fact_deposit'
              businnes_code = Param.where('factor_id=? and action_id=2 and param_description_id=11', f.id).last.value
              query = "
                select div.code, abs(sum(dfp.base_amount)) as deposit
                  from "+FIN_OWNER+".credit_deposit_value dfp,
                    (SELECT ID FROM FIN.credit_deposit_factor t
                      CONNECT BY PRIOR t.ID = t.PARENT_ID START WITH id =15) tree, 
                    (SELECT d.id, d.name, d.code FROM "+FIN_OWNER+".division d where d.fact=1) div
                  where dfp.division_id = div.id and
                    dfp.sr_busines_id like (select id from "+FIN_OWNER+".sr_busines where code = '"+businnes_code+"')
                    and dfp.credit_deposit_factor_id =tree.id
                    and dfp.periods_id=(select id from "+FIN_OWNER+".periods where date_from = TO_DATE('"+
                    period.end_date.to_s+"','yyyy-mm-dd')) group by div.code"
              facts.clear
              PlanDictionary.find_by_sql(query).each {|fact|
                facts[fact.code] = fact.deposit
              }
            end
            if f.fact_descriptor == 'get_fact_card_count'
              cursor = get_cursor odb_connect, get_odb_function(function_name, period.end_date, nil, 'D', program_names)
              # r[0] => division_id; r[1] => amount
              facts.clear
              while r = cursor.fetch()
                code = get_code_s_by_odb_division_id r[0], direction.id
                facts[code] = r[1]
              end
            end
            # Количество овердрафтов на счет 2605 
            if f.fact_descriptor == 'get_fact_count_card_over'  
              query = " 
                declare
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                begin "+program_names_to_array(program_names)+
                  FACT_OWNER+".vbr_kpi.get_pers_card_over(TO_DATE('"+ 
                  period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, :c_cursor);
                end; "
              cursor = get_cursor odb_connect, query

              # r[0] => division_id; r[1] => overs; r[2] => cards
              facts.clear
              while r = cursor.fetch()
                code = get_code_s_by_odb_division_id r[0], direction.id
                if (code == '000') and (f.id == 279) # Количество установленных овердрафтов на счет 2605
                  code = '002'
                end
                facts[code] = r[1]
              end
            end
            # Процент покрытия карт лимитами на дату 
            if f.fact_descriptor == 'get_fact_card_over'  
              query = " 
                declare
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                begin "+program_names_to_array(program_names)+
                  FACT_OWNER+".vbr_kpi.get_pers_card_over(TO_DATE('"+ 
                  period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, :c_cursor);
                end; "
              cursor = get_cursor odb_connect, query

              # r[0] => division_id; r[1] => overs; r[2] => cards
              facts.clear
              a_c = 0
              ov = 0
              reg_act = {}
              reg_ov = {}
              while r = cursor.fetch()
                code = get_code_s_by_odb_division_id r[0], direction.id
                if facts[code].nil?
                  facts[code] = 0
                end
                ov = ov+(r[1] ? r[1]:0)
                if (r[2].nil?) or (r[2]==0)
                else
                  a_c = a_c+r[2]
                  if not r[1].nil?
                    facts[code] = r[1]*100/r[2]
                  end
                end
                if (direction.level_id == 2) and (r[0].to_i != 1) and (r[0].to_i != 322) # 000 & 019
                  reg_id = get_fd_region_id(r[0])
                  reg_ov[reg_id] = (reg_ov[reg_id] ? reg_ov[reg_id]:0)+(r[1] ? r[1]:0)
                  reg_act[reg_id] = (reg_act[reg_id] ? reg_act[reg_id]:0)+(r[2] ? r[2]:0)
                end
              end
              if a_c != 0
                fact_of_bank = ov*100/a_c
              end
              if direction.level_id == 2
                reg_act.each {|id, value|
                  facts_by_regions[id] = 0
                  if value != 0
                    facts_by_regions[id]=reg_ov[id]*100/value
                  end
                }
              end
            end
            # Процент покрытия зарплатных карт лимитами на дату 
            if f.fact_descriptor == 'get_fact_card_over_icz'  
              query = " 
                declare
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                begin "+program_names_to_array(program_names)+
                  FACT_OWNER+".vbr_kpi.get_pers_card_over_icz(TO_DATE('"+ 
                  period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, :c_cursor);
                end; "
              cursor = get_cursor odb_connect, query

              # r[0] => division_id; r[1] => type_id; r[2] => overs; r[3] => cards; r[4] => active_cards
              facts.clear
              a_c = 0
              ov = 0
              reg_act = {}
              reg_ov = {}
              while r = cursor.fetch()
                code = get_code_s_by_odb_division_id r[0], direction.id
                if facts[code].nil?
                  facts[code] = 0
                end
                if r[1].to_i == 14692
                  ov = ov+(r[2] ? r[2]:0)
                  if (r[4].nil?) or (r[4]==0)
                  else
                    a_c = a_c+r[4]
                    if not r[2].nil?
                      facts[code] = r[2]*100/r[4]
                    end
                  end
                  if (direction.level_id == 2) and (r[0].to_i != 1) and (r[0].to_i != 322) # 000 & 019
                    reg_id = get_fd_region_id(r[0])
                    reg_ov[reg_id] = (reg_ov[reg_id] ? reg_ov[reg_id]:0)+(r[2] ? r[2]:0)
                    reg_act[reg_id] = (reg_act[reg_id] ? reg_act[reg_id]:0)+(r[4] ? r[4]:0)
                  end
                end
              end
              if a_c != 0
                fact_of_bank = ov*100/a_c
              end
              if direction.level_id == 2
                reg_act.each {|id, value|
                  facts_by_regions[id] = 0
                  if value != 0
                    facts_by_regions[id]=reg_ov[id]*100/value
                  end
                }
              end
            end
            if f.fact_descriptor == 'get_fact_card_ick' # процент охвата зарплатных карт кредитными 
              query = " 
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                begin "+
                  FACT_OWNER+".vbr_kpi.get_pers_card_ick(TO_DATE('"+period.end_date.to_s+"','yyyy-mm-dd'),:c_cursor);
                end; " 
              cursor = get_cursor odb_connect, query

              # r[0] => division_id; r[1] => type_id; r[2] => cards; r[3] => cred_card
              facts.clear
              card = 0
              cred = 0
              reg_card = {}
              reg_cred = {}
              while r = cursor.fetch()
                code = get_code_s_by_odb_division_id r[0], direction.id
                if facts[code].nil?
                  facts[code] = 0
                end
                if r[1].to_i == 15633
                  card = card +(r[2] ? r[2]:0)
                  cred = cred +(r[3] ? r[3]:0)
                  if not r[2].nil? and (r[2]!=0)
                    if not r[3].nil?
                      facts[code] = r[3]*100/r[2]
                    end  
                    if (direction.level_id == 2) and (r[0].to_i != 1) and (r[0].to_i != 322) # 000 & 019
                      reg_id = get_fd_region_id(r[0])
                      reg_cred[reg_id] = (reg_cred[reg_id] ? reg_cred[reg_id]:0)+(r[3] ? r[3]:0)
                      reg_card[reg_id] = (reg_card[reg_id] ? reg_card[reg_id]:0)+(r[2] ? r[2]:0)
                    end
                  end
                end
              end
              if card != 0
                fact_of_bank = cred*100/card
              end
              if direction.level_id == 2
                reg_card.each {|id, value|
                  facts_by_regions[id] = 0
                  if value != 0
                    facts_by_regions[id]=reg_cred[id]*100/value
                  end
                }
              end
            end
            if f.fact_descriptor == 'get_count_term' # Количество терминальных устройств на дату
              terminal_type = Param.where('factor_id=? and action_id=2 and param_description_id=10', f.id).last.value
              cursor = get_cursor odb_connect, get_odb_function(function_name, period.end_date, nil, 'D', terminal_type)
              # r[0] => division_id; r[1] => amount
              facts.clear
              while r = cursor.fetch()
                code = get_code_s_by_odb_division_id r[0], direction.id
                facts[code] = r[1]
              end
            end
            if f.fact_descriptor == 'get_fact_open_accounts' 
              cursor = get_cursor odb_connect, get_odb_function(function_name, period.end_date, nil, 'D', program_names)
              # r[0] => division_id; r[1] => amount; r[2] => amount_cb; r[3] => amount_gsm; r[4] => amount_active
              
              facts.clear
              while r = cursor.fetch()
                code = get_code_s_by_odb_division_id r[0], direction.id
                facts[code] = r[1]
              end
            end
            if f.fact_descriptor == 'get_fact_open_accounts_from_fd'
              query = "
                select  
                  sum(cdv.cnt) acc,         --Количество текущих счетов
                  d.code          --Код отделения
                from "+FIN_OWNER+".credit_deposit_value cdv,
                  "+FIN_OWNER+".credit_deposit_factor cdf,
                  "+FIN_OWNER+".division d,
                  "+FIN_OWNER+".sr_busines b,
                  "+FIN_OWNER+".sr_currency c
                where cdv.credit_deposit_factor_id = cdf.id
                  and cdv.division_id = d.id
                  and b.id = cdv.sr_busines_id
                  and c.id = cdv.sr_currency_id
                  and cdf.type=2 --Тип - текущие счета
                  and b.code = 'K'
                  and c.short_name = 'UAH'
                  and cdv.periods_id in (select id from fin.periods p 
                      where p.type_period='M' and p.date_from = TO_DATE('"+period.start_date.to_s+"','yyyy-mm-dd'))
                group by d.code order by d.code"
              facts.clear
              PlanDictionary.find_by_sql(query).each {|a| facts[a.code] = a.acc}   
              if direction.level_id == 2
                facts.each {|co, value|
                  facts_by_regions[parents[co]] = (facts_by_regions[parents[co]] ? facts_by_regions[parents[co]] : 0) + value
                }
              end
            end
            if f.fact_descriptor == 'get_fact_percent_accounts_active_from_fd'
              query = "
                select  
                  sum(cdv.cnt) acc,         --Количество текущих счетов
                  sum(cdv.cnt2) act,        --Количество активных счетов
                  d.code          --Код отделения
                from "+FIN_OWNER+".credit_deposit_value cdv,
                  "+FIN_OWNER+".credit_deposit_factor cdf,
                  "+FIN_OWNER+".division d,
                  "+FIN_OWNER+".sr_busines b,
                  "+FIN_OWNER+".sr_currency c
                where cdv.credit_deposit_factor_id = cdf.id
                  and cdv.division_id = d.id
                  and b.id = cdv.sr_busines_id
                  and c.id = cdv.sr_currency_id
                  and cdf.type=2 --Тип - текущие счета
                  and b.code = 'K'
                  and c.short_name = 'UAH'
                  and cdv.periods_id in (select id from fin.periods p 
                    where p.type_period='M' and p.date_from = TO_DATE('"+period.start_date.to_s+"','yyyy-mm-dd'))
                group by d.code order by d.code"
              acc = 0.0
              act = 0.0
              reg_acc = {}
              reg_act = {}
              facts.clear
              PlanDictionary.find_by_sql(query).each {|a|
                facts[a.code] = 0
                acc += a.acc
                act += a.act
                if a.acc!=0
                  if a.act!=0
                    facts[a.code] = a.act.to_f*100/a.acc.to_f
                  end
                end  
                if (direction.level_id == 2) and (a.code != '000') and (a.code != '019')
                    reg_id = parents[a.code]
                    reg_acc[reg_id] = (reg_acc[reg_id] ? reg_acc[reg_id]:0)+a.acc
                    reg_act[reg_id] = (reg_act[reg_id] ? reg_act[reg_id]:0)+a.act
                end
              }              
              if acc != 0
                fact_of_bank = act.to_f*100/acc.to_f
              end
              if direction.level_id == 2
                reg_acc.each {|id, value|
                  facts_by_regions[id] = 0
                  if value != 0
                    facts_by_regions[id]=reg_act[id]*100/value
                  end
                }
              end
            end
            if f.fact_descriptor == 'get_fact_percent_accounts_active' 
              cursor = get_cursor odb_connect, get_odb_function(function_name, period.end_date, nil, 'D', program_names)
#              program_names = Param.where('factor_id=? and action_id=2 and param_description_id=6', f.id).last.value
#              query = " 
#                declare
#                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
#                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
#                begin "+program_names_to_array(program_names)+
#                  FACT_OWNER+".vbr_kpi.get_count_tariff(TO_DATE('"+ 
#                  period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, :c_cursor);
#                end; "   
#              cursor = get_cursor odb_connect, query
              # r[0] => division_id; r[1] => amount; r[2] => amount_cb; r[3] => amount_gsm; r[4] => amount_active
              acc = 0
              act = 0
              reg_acc = {}
              reg_act = {}
              facts.clear
              while r = cursor.fetch()
                code = get_code_s_by_odb_division_id r[0], direction.id
                if facts[code].nil?
                  facts[code] = 0
                end
                acc = acc +(r[1] ? r[1]:0)
                act = act +(r[4] ? r[4]:0)
                if not r[1].nil? and (r[1]!=0)
                  if not r[4].nil?
                    facts[code] = r[4]*100/r[1]
                  end  
                  if (direction.level_id == 2) and (r[0].to_i != 1) and (r[0].to_i != 322) # 000 & 019
                    reg_id = get_fd_region_id(r[0])
                    reg_acc[reg_id] = (reg_acc[reg_id] ? reg_acc[reg_id]:0)+(r[1] ? r[1]:0)
                    reg_act[reg_id] = (reg_act[reg_id] ? reg_act[reg_id]:0)+(r[4] ? r[4]:0)
                  end
                end
              end
                            
              if acc != 0
                fact_of_bank = act*100/acc
              end
              if direction.level_id == 2
                reg_acc.each {|id, value|
                  facts_by_regions[id] = 0
                  if value != 0
                    facts_by_regions[id]=reg_act[id]*100/value
                  end
                }
              end
            end  
            if f.fact_descriptor == 'get_fact_percent_kb_servises_using' 
              cursor = get_cursor odb_connect, get_odb_function(function_name, period.end_date, nil, 'D', program_names)
              # r[0] => division_id; r[1] => amount; r[2] => amount_cb; r[3] => amount_gsm; r[4] => amount_active
              acc = 0
              srv = 0
              reg_acc = {}
              reg_srv = {}
              facts.clear
              while r = cursor.fetch()
                code = get_code_s_by_odb_division_id r[0], direction.id
                if facts[code].nil?
                  facts[code] = 0
                end
                acc = acc +(r[1] ? r[1]:0)
                srv = srv +(r[2] ? r[2]:0)+(r[3] ? r[3]:0)
                if not r[1].nil? and (r[1]!=0)
                  if (not r[2].nil?) or (not r[3].nil?)
                    facts[code] = ((r[2] ? r[2]:0)+(r[3] ? r[3]:0))*100/r[1]
                  end  
                  if (direction.level_id == 2) and (r[0].to_i != 1) and (r[0].to_i != 322) # 000 & 019
                    reg_id = get_fd_region_id(r[0])
                    reg_acc[reg_id] = (reg_acc[reg_id] ? reg_acc[reg_id]:0)+(r[1] ? r[1]:0)
                    reg_srv[reg_id] = (reg_srv[reg_id] ? reg_srv[reg_id]:0)+(r[2] ? r[2]:0)+(r[3] ? r[3]:0)
                  end
                end
              end
              if acc != 0
                fact_of_bank = srv*100/acc
              end
              if direction.level_id == 2
                reg_acc.each {|id, value|
                  facts_by_regions[id] = 0
                  if value != 0
                    facts_by_regions[id]=reg_srv[id]*100/value
                  end
                }
              end
            end                       
            if f.fact_descriptor == 'get_fact_percent_kb_service_using' 
              cursor = get_cursor odb_connect, get_odb_function(function_name, period.end_date, nil, 'D', program_names)
              # r[0] => division_id; r[1] => amount; r[2] => amount_cb; r[3] => amount_gsm; r[4] => amount_active
              acc = 0
              cb = 0
              reg_acc = {}
              reg_srv = {}
              facts.clear
              while r = cursor.fetch()
                code = get_code_s_by_odb_division_id r[0], direction.id
                facts[code] = 0 if facts[code].nil?
                acc = acc +(r[1] ? r[1]:0)
                cb = cb +(r[2] ? r[2]:0)
                if not r[1].nil? and (r[1]!=0)
                  if (not r[2].nil?) 
                    facts[code] = (r[2] ? r[2]:0)*100/r[1]
                  end  
                  if (direction.level_id == 2) and (r[0].to_i != 1) and (r[0].to_i != 322) # 000 & 019
                    reg_id = get_fd_region_id(r[0])
                    reg_acc[reg_id] = (reg_acc[reg_id] ? reg_acc[reg_id]:0)+(r[1] ? r[1]:0)
                    reg_srv[reg_id] = (reg_srv[reg_id] ? reg_srv[reg_id]:0)+(r[2] ? r[2]:0)
                  end
                end
              end
              fact_of_bank = cb*100/acc if (acc != 0)
              if direction.level_id == 2
                reg_acc.each {|id, value|
                  facts_by_regions[id] = 0
                  if value != 0
                    facts_by_regions[id]=reg_srv[id]*100/value
                  end
                }
              end
            end                       
            if f.fact_descriptor == 'get_fact_percent_gsm_service_using' 
              cursor = get_cursor odb_connect, get_odb_function(function_name, period.end_date, nil, 'D', program_names)
              # r[0] => division_id; r[1] => amount; r[2] => amount_cb; r[3] => amount_gsm; r[4] => amount_active
              acc = 0
              srv = 0
              reg_acc = {}
              reg_srv = {}
              facts.clear
              while r = cursor.fetch()
                code = get_code_s_by_odb_division_id r[0], direction.id
                facts[code] = 0 if facts[code].nil?
                acc = acc +(r[1] ? r[1]:0)
                srv = srv +(r[3] ? r[3]:0)
                if not r[1].nil? and (r[1]!=0)
                  if (not r[3].nil?) 
                    facts[code] = (r[3] ? r[3]:0)*100/r[1]
                  end  
                  if (direction.level_id == 2) and (r[0].to_i != 1) and (r[0].to_i != 322) # 000 & 019
                    reg_id = get_fd_region_id(r[0])
                    reg_acc[reg_id] = (reg_acc[reg_id] ? reg_acc[reg_id]:0)+(r[1] ? r[1]:0)
                    reg_srv[reg_id] = (reg_srv[reg_id] ? reg_srv[reg_id]:0)+(r[3] ? r[3]:0)
                  end
                end
              end
              fact_of_bank = srv*100/acc if (acc != 0)
              if direction.level_id == 2
                reg_acc.each {|id, value|
                  if value != 0
                    facts_by_regions[id]=reg_srv[id]*100/value
                  else
                    facts_by_regions[id] = 0
                  end
                }
              end
            end                       
            if f.fact_descriptor == 'get_fact_enroll_salary'
              cursor = get_cursor odb_connect, get_odb_function(function_name, period.start_date, period.end_date, 'D', program_names)
              # r[0] => division_id; r[1] => amount; r[2] => count
              facts.clear
              while r = cursor.fetch()
                code = get_code_s_by_odb_division_id r[0], direction.id
                if (code == '000') and (f.id == 240) and (program_names == 'KZPK') # Сумма зачислений з/п по коммерческим зарплатным проектам
                  code = '002'
                end
                facts[code] = r[1]
              end
            end
# save this code!
#            if f.fact_descriptor == 'get_fact_percent_accounts_active' 
#              query = "
#                declare
#                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
#                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
#                begin 
#                  m_macro_table.extend;
#                  m_macro_table(1) := "+FACT_OWNER+".T_STR_ROW('KSTG'); "+
#                  FACT_OWNER+".vbr_kpi.get_count_tariff(TO_DATE('"+
#                  period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, :c_cursor);
#                end;"
#              cursor = get_cursor odb_connect, query
#
#              # r[0] => division_id
#              # r[1] => amount
#              # r[2] => amount_cb
#              # r[3] => amount_gsm
#              # r[4] => amount_active
#              facts.clear
#              while r = cursor.fetch()
#                code = get_code_s_by_odb_division_id r[0], direction.id
#                if (not r[1].nil?) and (r[1]!=0)
#                  if r[4].nil?
#                    facts[code] = 0
#                  else
#                    facts[code] = r[4]*100/r[1]
#                  end
#                else
#                  facts[code] = 0
#                end
#              end
#            end
            if f.fact_descriptor == 'get_fact_credit_contract_number' 
              query = "
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                begin "+program_names_to_array(program_names)+
                  FACT_OWNER+".vbr_kpi.get_count_credit(TO_DATE('"+
                  period.end_date.to_s+"','yyyy-mm-dd'), 'T', m_macro_table, :c_cursor);
                end;"
              cursor = get_cursor odb_connect, query
              # r[0] => division_id; r[1] => user_id; r[2] => contract_amount
              facts_by_worker.clear
              while r = cursor.fetch()
                e = Employee.find_by_sr_user_id(r[1])
                if not e.nil?
                  pers_number = e.tabn.to_i
                  facts_by_worker[pers_number] = r[2]
                end  
              end
              query = "
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                begin "+program_names_to_array(program_names)+
                  FACT_OWNER+".vbr_kpi.get_count_credit(TO_DATE('"+
                  period.start_date.yesterday.to_s+"','yyyy-mm-dd'), 'T', m_macro_table, :c_cursor);
                end;"
              cursor = get_cursor odb_connect, query
              while r = cursor.fetch()
                e = Employee.find_by_sr_user_id(r[1])
                if not e.nil?
                  pers_number = e.tabn.to_i
                  if not facts_by_worker[pers_number].nil?
                    facts_by_worker[pers_number] = facts_by_worker[pers_number]-r[2]
                  else
                    facts_by_worker[pers_number] = r[2]
                  end  
                end  
              end
            end
            if f.fact_descriptor == 'get_fact_credit_value_msb'
              query = "    
                select sum(cdv.base_amount) as credit, d.code                              
                from "+FIN_OWNER+".credit_deposit_value cdv,
                  "+FIN_OWNER+".credit_deposit_factor cdf,
                  "+FIN_OWNER+".division d,
                  "+FIN_OWNER+".periods p,
                  "+FIN_OWNER+".sr_busines b
                where cdv.credit_deposit_factor_id = cdf.id
                  and cdv.division_id = d.id
                  and p.id = cdv.periods_id
                  and b.id = cdv.sr_busines_id
                  and p.date_from = to_date('"+period.end_date.to_s+"','yyyy-mm-dd')
                  and cdf.type=0 --Тип: 0 - кредиты/ 1 - депозиты
                  and b.code = 'M' 
                group by d.code"    
              
              facts.clear
              PlanDictionary.find_by_sql(query).each {|fact|
                facts[fact.code] = fact.credit
              }
            end
#            if f.fact_descriptor == 'get_fact_over_average'
#              businnes_code = Param.where('factor_id=? and action_id=2 and param_description_id=11', f.id).last.value
#              query = "
#                select d.code, abs(sum(dfp.base_amount)) as base_amount_all
#                  from "+FIN_OWNER+".credit_deposit_value dfp,
#                    "+FIN_OWNER+".division d,
#                    (SELECT ID FROM "+FIN_OWNER+".credit_deposit_factor t
#                      CONNECT BY PRIOR t.ID = t.PARENT_ID START WITH id =25) tree
#                  where  dfp.sr_busines_id like (select id from "+FIN_OWNER+".sr_busines where code = '"+businnes_code+"')
#                    and dfp.division_id = d.id
#                    and dfp.credit_deposit_factor_id =tree.id
#                    and dfp.periods_id="+period.id.to_s+" group by d.code order by d.code"              
#              facts.clear
#              PlanDictionary.find_by_sql(query).each {|over|
#                facts[over.code] = over.base_amount_all
#              }
#            end
            if f.fact_descriptor == 'get_fact_from_result'
              direction_id = Param.where('factor_id=? and action_id=2 and param_description_id=12', f.id).last.value
              facts.clear
              facts_by_regions.clear
              Performance.where("block_id = 0 and period_id=? and direction_id=? and calc_date in (
                select max(calc_date) from performances where block_id = 0 and period_id=? and direction_id=? 
                group by division_id)",period.id, direction_id, period.id, direction_id).order(:division_id).each{|ev|
                  facts[code_by_id[ev.division_id]] = ev.kpi
                }
            end
            if f.fact_descriptor == 'get_fact_from_result_for_directions'
              direction_id = Param.where('factor_id=? and action_id=2 and param_description_id=12', f.id).last.value
              facts.clear
              facts_by_regions.clear
              cnt_div_by_dir = {}
              query = f.id == 274 ? "select parent_id, count(*) cnt from "+FIN_OWNER+
                ".division where open_date is not null and parent_id > 1 group by parent_id" :
                "select parent_id, count(*) cnt from "+FIN_OWNER+".division d
                  join "+FIN_OWNER+".division_branch_hist dbh on d.id = dbh.id_division and dbh.id_division_branch in (3, 4) and 
                  dbh.modify_date in (select max(dbh.modify_date) as modify_date
                  from "+FIN_OWNER+".division_branch_hist dbh 
                  where dbh.modify_date<=to_date('"+period.start_date.to_s+"','yyyy-mm-dd') group by dbh.id_division)
                  where open_date is not null and parent_id > 1 group by parent_id"
#              s = f.id == 274 ? '' : ' and division_branch_id in (3, 4) ' # для ИБ не учитываем категорию отделения ШИА 25.04.12
              BranchOfBank.find_by_sql(query).each {|rd|
                cnt_div_by_dir[rd.parent_id] = rd.cnt
              }
 
              id_divs_by_dir = {}
              ids = []
              cnt_div_by_dir.each {|k, v|
                ids.clear
                BranchOfBank.find_by_sql("select id from fin.division where parent_id ="+k.to_s+s+
                  "  and open_date is not null").each {|d| ids << d.id}
                id_divs_by_dir[k] = ids.join(',') 
              }                               
              BranchOfBank.where("parent_id = 1 and id != 40  and open_date is not null").each {|rd|
                Performance.find_by_sql("SELECT sum(kpi) res FROM performances WHERE 
                  block_id = 0 and period_id="+period.id.to_s+" and direction_id="+
                  direction_id.to_s+" and division_id in ("+id_divs_by_dir[rd.id].to_s+") and
                  calc_date in (select max(calc_date) from performances where block_id = 0 and period_id="+period.id.to_s+"
                  and direction_id="+direction_id.to_s+" group by division_id)").each {|ev| 
                  facts_by_regions[rd.id] = ev.res.to_f/cnt_div_by_dir[rd.id]
                } 
              }              
            end
            if f.fact_descriptor == 'get_fact_fin_res_by_interval'
                article = Param.where('factor_id=? and action_id=2 and param_description_id=5', f.id).last.value
                business = Param.where('factor_id=? and action_id=2 and param_description_id=11', f.id).last.value
                query = "
                  select division_id, sum(decode(fpv.period_id, p_b.id, fpv.value, -fpv.value)) as fact
                  from "+FIN_OWNER+".finres_value fpv,
                  (select id from "+FIN_OWNER+".periods p where p.date_to = to_date('"+
                    (period.end_date.month == 1 ? period.start_date.to_s :
                    period.start_date.yesterday.to_s)+"','yyyy-mm-dd') and p.type_period = 'D') p_b,
                  (select id from "+FIN_OWNER+".periods p where p.date_from = to_date('"+
                    period.end_date.to_s+"','yyyy-mm-dd') and p.type_period = 'D') p_e
                  where fpv.period_id in (p_b.id, p_e.id)
                    and fpv.sr_busines_id in (select id from "+FIN_OWNER+".sr_busines where code = '"+business+"')
                    and fpv.finres_directory_id in (select id from "+FIN_OWNER+".finres_directory where code in ("+article+"))
                  group by division_id order by division_id"
                facts.clear
                PlanDictionary.find_by_sql(query).each {|fr|
                  facts[code_by_id[fr.division_id]] = fr.fact
                }
            end
          end
          case direction.level_id 
            when 4
              prepare_and_save_kpi_by_workers code_by_id, plans_by_worker, facts_by_worker, plans, facts, direction, f.block_id, f.id, period.id, 
                b.block_weights.last.weight, f.factor_weights.last.weight
            when 2    
              prepare_and_save_kpi_by_regions parents, plans, facts_by_regions, facts, direction, f.block_id, f.id, period.id, 
                b.block_weights.last.weight, f.factor_weights.last.weight
            else
              prepare_and_save_kpi code_by_id, plans, fact_of_bank, facts, direction, f.block_id, f.id, period.id, 
                b.block_weights.last.weight, f.factor_weights.last.weight
          end  
        end
      end 
    end
  end
  
  def get_cursor odb_connect, query
    plsql = odb_connect.parse(query)
    plsql.bind_param(':c_cursor', OCI8::Cursor) 
    plsql.exec
    cursor = plsql[':c_cursor']
    plsql.close
    return cursor          
  end

  def prepare_and_save_kpi_by_workers code_by_id, plans_by_worker, facts_by_worker, plans, facts, direction, block_id, factor_id, period_id, bw, fw
    factor = Factor.find(factor_id)
    @workers.each {|w|
      code = w.code_division[0, 3]
      fullname = w.lastname+' '+w.firstname+' '+w.soname
      if plans_by_worker[w.id.to_i] and not plans_by_worker[w.id.to_i].nil?
        plan = plans_by_worker[w.id.to_i]
      else
        plan = (plans[code] and not plans[code].nil?) ? plans[code] : 0
      end

      fact = 0
      fact = facts_by_worker[w.tabn.to_i].nil? ? (facts[code].nil? ? 0 : facts[code]) : (facts_by_worker[w.tabn.to_i])
      percent = get_percent plan, fact, factor
  
      rate = bw * fw
      kpi = get_spec_kpi percent, rate, factor.factor_description_id    
      save_kpi period_id, code_by_id.key(code), direction.id, block_id, factor_id, 
        w.id, fullname, rate, plan, fact, percent, kpi 
    }
  end

  def prepare_and_save_kpi code_by_id, plans, fact_of_bank, facts, direction, block_id, factor_id, period_id, bw, fw
    plan = 0
    fact = 0
    factor = Factor.find(factor_id)
    case direction.level_id
      when 1 # whole bank
        if Factor.find(factor_id).plan_descriptor == 'get_plan_const'
          plan = Param.where('factor_id=? and action_id=1 and param_description_id=8', factor_id).last.value.to_i
        else
          plans.each_value {|p| plan += (p ? p : 0)}
        end
        if factor.fact_descriptor == 'get_fact_from_values'
          fact = fact_of_bank
        else
          if (factor.factor_description.unit_id != 1) or (factor.block.block_description_id == 2)
            facts.each_value {|f| fact += (f ? f.to_f : 0)}
          else
            fact = fact_of_bank
          end 
        end
        percent = get_percent plan, fact, factor
        if factor.factor_description.short_name == "% проблемности"
          fact = 0 if fact == -1
        end
        rate = bw * fw
        kpi = get_spec_kpi percent, rate, factor.factor_description_id    
        save_kpi period_id, 999, direction.id, block_id, factor_id, 
          0, '', rate, plan, fact, percent, kpi 
      when 3 # all divisions
        plans.each {|code, value|
          plan = value ? value : 0
          fact = (not facts[code].nil?) ? facts[code] : 0
          percent = get_percent plan, fact, factor
          if factor.factor_description.short_name == "% проблемности"
            fact = 0 if fact == -1
          end
          if factor.block.categorization
#            category_id = BranchOfBank.find(code_by_id.key(code)).division_branch_id
            category_id = BranchOfBank.find(code_by_id.key(code)).category_histories.order(:modify_date).last.id_division_branch
            category_id = 3 if (category_id == 1) or (category_id == 2)
            category_id = 4 if (category_id == 5) or (category_id == 6)
            fw = FactorWeight.where("factor_id=? and division_category_id=?",factor_id, category_id).order(:id).last.weight
          end
          rate = bw * fw
          kpi = get_spec_kpi percent, rate, factor.factor_description_id
          save_kpi period_id, code_by_id.key(code), direction.id, block_id, factor_id, 
            0, # worker_id, 
            '', # fullname, 
            rate, plan, fact, percent, kpi 
        }
    end
  end

  def get_spec_kpi percent, rate, factor_description_id
# Согласовано с ШИА и ЕРА 23.01.2012
    if (percent < 0) and (factor_description_id == 1) # Финансовый результат без учета расходов поддержек
      return  0
    else
      return rate*percent
    end
  end
  
  def get_percent plan, fact, factor
    if factor.factor_description.short_name == "% проблемности"
      if fact == -1
        return 0
      else
        percent = get_problem_percent(factor.id, fact)
      end
    else
      if factor.factor_description_id == 1 # Финансовый результат без учета расходов поддержек
        percent = get_spec_percent plan, fact
      else  
        if (plan == 0) and (fact.to_f <= 0)
          percent = 0
        else
          if (plan == 0) and (fact.to_f > 0)
            percent = 100
          else
            percent = 100*fact.to_f/plan.to_f
          end
        end
        
      end
    end
    percent = 200 if percent > 200
    return percent    
  end

  def get_spec_percent plan, fact
    if plan == 0 and fact == 0
      return 100
    end
    if plan == 0
      if fact > 0
        return 100*fact
      else
        return 100/fact.abs
      end
    else    
      return ((fact-plan)/plan.abs+1)*100
    end  
  end
  
  def prepare_and_save_kpi_by_regions parents, plans, facts_by_regions, facts, direction, block_id, factor_id, period_id, bw, fw
    factor = Factor.find(factor_id)
    plans_by_regions = {}
#    if factor_id == 271 # Финансовый результат без учета расходов поддержек
#      BranchOfBank.where("parent_id = 1 and id != 40 and open_date is not null").each {|d|
#        plans_by_regions[d.id] = plans[d.code] 
#      }
#    end

    plans.each {|code, value|
      if code != '000' and code != '019'
        if factor.plan_descriptor == 'get_plan_const'
          plans_by_regions[parents[code]] = Param.where('factor_id=? and action_id=1 and param_description_id=8', factor_id).last.value.to_i
        else
#          if factor_id != 271  
            plans_by_regions[parents[code]] = (plans_by_regions[parents[code]].nil? ? 0 : plans_by_regions[parents[code]])+
              (value ? value : 0)
#          end  
        end  
        if (direction.id == 39) and (factor.id > 271 and factor.id <= 274) # Руководители дирекций ПАТ "ВБР"
        else  
          if (factor.factor_description.unit_id != 1) or (factor.block.block_description_id == 2)
            facts_by_regions[parents[code]] = (facts_by_regions[parents[code]].nil? ? 0 : facts_by_regions[parents[code]]).to_f+
              (facts[code].nil? ? 0 : facts[code]).to_f
          end 
        end
      end  
    }
    rate = bw * fw

    plans_by_regions.each {|region_id, plan| 
      fact = facts_by_regions[region_id]
      percent = get_percent plan, fact, factor
      kpi = get_spec_kpi percent, rate, factor.factor_description_id
      save_kpi period_id, region_id, direction.id, block_id, factor_id, 
        0, '', rate, plan, fact, percent, kpi 
    }  
  end
  
  def get_fd_region_id odb_division_id
    c = Division.find(odb_division_id).code
    code = c.to_i > 9 ? '0'+c : '00'+c
    if code == '001'
      return 1
    else
      return BranchOfBank.find_by_code(code).parent_id
    end  
  end
  
  def save_final_kpi period, direction, regions
    case direction.level_id
      when 1 
        perfs = Performance.where("factor_id > 0 and division_id = 999 and period_id=? and direction_id=? and calc_date in (
          select max(calc_date) from performances where factor_id > 0 and division_id = 999 and period_id=? and direction_id=? 
          group by factor_id order by factor_id)",
        period.id, direction.id, period.id, direction.id).order(:block_id)
        total_kpi = 0
        block_kpi = 0
        curr_block = perfs[0].block_id
        perfs.each {|p|  
          if p.factor.factor_weights.last.weight > 0.00001
            total_kpi += p.kpi
            if curr_block != p.block_id
              save_kpi period.id, 999, direction.id, curr_block, 0, 0, '', 0, 0, 0, 0, block_kpi
              curr_block = p.block_id
              block_kpi = p.kpi
            else
              block_kpi += p.kpi
            end
          end  
        }
        save_kpi period.id, 999, direction.id, curr_block, 0, 0, '', 0, 0, 0, 0, block_kpi
        save_kpi period.id, 999, direction.id, 0, 0, 0, '', 0, 0, 0, 0, total_kpi
      when 2, 3
        regions.each {|r|
          perfs = Performance.where("factor_id > 0 and division_id = ? and period_id=? and direction_id=? and calc_date in (
            select max(calc_date) from performances where factor_id > 0 and division_id = ? and period_id=? and direction_id=? 
            group by factor_id order by factor_id)",
          r.id, period.id, direction.id, r.id, period.id, direction.id).order(:block_id)
          total_kpi = 0
          block_kpi = 0
          curr_block = perfs[0].block_id
          perfs.each {|p|  
            if p.factor.factor_weights.last.weight > 0.00001
              total_kpi += p.kpi
              if curr_block != p.block_id
                save_kpi period.id, r.id, direction.id, curr_block, 0, 0, '', 0, 0, 0, 0, block_kpi
                curr_block = p.block_id
                block_kpi = p.kpi
              else
                block_kpi += p.kpi
              end
            end  
          }
          save_kpi period.id, r.id, direction.id, curr_block, 0, 0, '', 0, 0, 0, 0, block_kpi
          save_kpi period.id, r.id, direction.id, 0, 0, 0, '', 0, 0, 0, 0, total_kpi
        }
    end
  end
  
  def get_fields r, n_f
    worker = ''
    e = Employee.find_by_sr_user_id(r[1])
    if not e.nil?
      w = Worker.find_by_TABN e.tabn
      if w
        worker = w.LASTNAME+' '+w.FIRSTNAME+' '+w.SONAME
      end  
    end      
    case n_f
      when 3
        return {:division_name => Division.find(r[0]).name, :user => (worker>''? worker:r[1]), :object_id => r[2]}
      when 4
        return {:division_name => Division.find(r[0]).name, :user => (worker>''? worker:r[1]), :object_id => r[2], :amount_1 => r[3]}
      when 5
        return {:division_name => Division.find(r[0]).name, :user => (worker>''? worker:r[1]), :object_id => r[2], :amount_1 => r[3], :amount_2 => r[4]}
      when 6
        return {:division_name => Division.find(r[0]).name, :user => (worker>''? worker:r[1]), :object_id => r[2], :amount_1 => r[3], :amount_2 => r[4], :amount_3 => r[5]}
    end
  end  

  def get_odb_function function_name, date_1, date_2, level, program_names
    d1 = date_1 ? "TO_DATE('"+date_1.to_s+"','yyyy-mm-dd'), " : " "
    d2 = date_2 ? "TO_DATE('"+date_2.to_s+"','yyyy-mm-dd'), " : " "
    p = program_names > "" ? program_names_to_array(program_names) : " "
    m = program_names > "" ? "m_macro_table, " : " "
    t_d = function_name == 'tst_rest_by_ct_type' ? "'CREDIT_DOCUMENT', " : ""
#    query = "
    return "
      declare
        c_cursor "+FACT_OWNER+"."+PACKAGE+".common_cursor;
        m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
      begin "+p+FACT_OWNER+"."+PACKAGE+"."+function_name+"("+d1+d2+t_d+
        "'"+level+"', "+m+" :c_cursor);
      end;"
#    ::Rails.logger.info query+"<++++++++++++++++++++++++++++>"  
#    return query  
  end
    
  def get_detailed_objects cursor, level, num_fields, odb_division_ids, op1, op2
    while r = cursor.fetch()
      case level
        when 1
          @total_1 = (op1 == 'SUM' ? @total_1+r[3]: @total_1+1) if op1>''
          @total_2 = (op2 == 'SUM' ? @total_2+r[4]: @total_2+1) if op2>''
          @objects << get_fields(r, num_fields)
        when 3
          if (odb_division_ids.include? r[0])
            @objects << get_fields(r, num_fields) 
            @total_1 = (op1 == 'SUM' ? @total_1+r[3]: @total_1+1) if op1>''
            @total_2 = (op2 == 'SUM' ? @total_2+(r[4] ? r[4]:0): @total_2+1) if op2>''
          end  
      end    
    end
  end
#                RAILS_DEFAULT_LOGGER.info plans.values
#                  ::Rails.logger.info query+"++++++++++++++++++++++++++++"
#                  ::Rails.logger.info r[0].to_s+"=>"+r[2].to_s+", "+r[3].to_s+"++++++++++++++++++++++++++++"
#                p plan_fact.to_s+"++++++++++++++++++++++++++++"
  
end

