# coding: utf-8
class PerformancesController < ApplicationController
  PLAN_OWNER = 'RPK880508'
  FACT_OWNER = 'SR_BANK'
  FIN_OWNER = 'FIN'
  def index
    @performances = Performance.order(:period_id, :direction_id, :division_id, :block_id, :factor_id)
  end

  def show_values
    @values = Performance.where('division_id=? and direction_id=? and factor_id=? and calc_date in(
      select max(calc_date) from performances where division_id=? and direction_id=? and factor_id=? 
      group by period_id order by period_id)',params[:division_id], params[:direction_id], params[:factor_id],
      params[:division_id], params[:direction_id], params[:factor_id]).order(:period_id)
    
  end
    
  def get_report_params
  end

  def get_report_division
    @direction = Direction.find params[:direction_id]
    @period = Period.find params[:period_id]
  end
  
  def get_report_params_2
    direction = Direction.find params[:report_params][:direction_id]
    case direction.level_id 
      when 1 then # whole the bank
        redirect_to :action => :show_report, 
          :report_params => {:period_id => params[:report_params][:period_id], 
                             :division_id =>  '1', 
                             :direction_id => direction.id}
      else # divisions and regions
        redirect_to :action => :get_report_division, :direction_id => direction.id, 
          :period_id => params[:report_params][:period_id]
    end
  end

  def get_calc_division
    @direction = Direction.find params[:direction_id]
    @period = Period.find params[:period_id]
  end
  
  def get_calc_params_2
    direction = Direction.find params[:report_params][:direction_id]
    case direction.level_id 
      when 1 then # whole the bank
        redirect_to :action => :calc_kpi, 
          :report_params => {:division_id =>  '1'}, 
                             :period_id => params[:report_params][:period_id],
                             :direction_id => direction.id
      when 4 then # by worker
        redirect_to :action => :get_calc_worker, :period_id => params[:report_params][:period_id],
                             :direction_id => direction.id                             
      else # divisions and regions
        redirect_to :action => :get_calc_division, :direction_id => direction.id, 
          :period_id => params[:report_params][:period_id]
    end
  end
  
  def get_calc_worker
    @direction = Direction.find params[:direction_id]
    @period = Period.find params[:period_id]
  end
  
  def get_calc_params
  end

#  def calc_worker_kpi
#    direction = Direction.find params[:direction_id]
#    period = Period.find(params[:period_id])
#  end
  
  def calc_kpi
    if params[:report_params][:worker_id]
      w = Worker.select('code_division, lastname, firstname, soname').where('id_emp=?',params[:report_params][:worker_id]).first
      code_division = w.code_division[0,3]
      d = BranchOfBank.where("code = ?",code_division).first
      fd_division_id = d.id
    else
      fd_division_id = params[:report_params][:division_id]
    end
    
    direction = Direction.find params[:direction_id]
    period = Period.find(params[:period_id])
    odb_division_ids = []
    odb_division_ids = get_odb_division_ids fd_division_id #params[:report_params][:division_id]
    odb_connection = OCI8.new("kpi", "R4EW9OLK", "srbank")
    for b in direction.blocks do  
      for f in b.factors do
        if f.factor_weights.last.weight > 0.00001
          if f.articles.nil? or f.articles.size==0
            plan = 0
            fact = 0
          else
            plan = get_plan period, params[:report_params][:division_id], f.id
            plan = plan ? plan : 0
            fact = get_fact odb_connection, odb_division_ids, f.id, period
            fact = (fact ? fact : 0)
          end
          bw = b.block_weights.last
          fw = f.factor_weights.last
          rate = bw.weight * fw.weight
          if f.factor_description.short_name == "% проблемности"
            case fact
              when 0..0.000001 then
                percent = 120
              when 0.0000101..0.015 then
                percent = 100
              when 0.0150001..0.02 then
                percent = 90
              when 0.0200001..0.025 then
                percent = 70
              when 0.0250001..0.04 then
                percent = 50
              when 0.0400001..0.07 then
                percent = 0
              else  
                percent = -100
            end    
          else
            percent = ((plan and (plan != 0))  ? 100*fact.to_f/plan.to_f : 0)
          end
          kpi = rate*percent
          save_kpi params[:period_id],
            params[:report_params][:division_id], 
            params[:direction_id],
            b.id, f.id, rate, plan, fact, percent, kpi
        end
      end
    end
    odb_connection.logoff
    redirect_to :action => :show_report, 
      :report_params => {:period_id => params[:period_id], 
      :division_id =>  params[:report_params][:division_id], 
      :direction_id => params[:direction_id]}
  end
    
  def show_report
    if params[:period_id]
      period_id = params[:period_id]
    else  
      period_id = params[:report_params][:period_id]
    end
    if params[:division_id]
      division_id = params[:division_id]
    else  
      division_id = params[:report_params][:division_id]
    end
    if params[:direction_id]
      direction_id = params[:direction_id]
    else  
      direction_id = params[:report_params][:direction_id]
    end
    get_kpi period_id, division_id, direction_id
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
  
  private

  def get_plans start_date, end_date, codes
    s_m = start_date.month
    e_m = end_date.month
    m_a = []
    bp_a = []
    res = ''
    codes.each {|c|
      al = 'r'+c
      for i in s_m..e_m
        res = res+al+'.plan_'+i.to_s+'+'
      end
    }
    return res[0, res.length-1]
  end

  def build_sql_for_results period_id, codes, article_name 
    p = Period.find(period_id)

    return  "select ("+get_plans(p.start_date.beginning_of_year, p.end_date, codes)+
      ") as plan from "+PLAN_OWNER+".directory d "+
      get_joins_for_result(codes)+
      " where d.namepp in '"+article_name+"'"
    
  end

  def get_fd_ids division_id
    fd_ids = []
    if division_id == '1' # whole the bank
      BranchOfBank.select(:id).where("code > '000' and code < '900' and open_date is not null").collect { 
        |d| fd_ids << d.id
      }  
    else
      division = BranchOfBank.find division_id
      if division.parent_id == 1 and not division.open_date.nil?
        BranchOfBank.select(:id).where("parent_id=?", division_id).collect {|d| fd_ids << d.id}
      else
        fd_ids << division.id
      end
    end
    return fd_ids
  end

  def get_codes division_id
    codes = []
    if division_id == '1' # whole the bank
      codes << '000'
      BranchOfBank.select(:code).where("code > '000' and code < '900' and open_date is not null").collect { 
        |d| codes << d.code
      }  
    else
      division = BranchOfBank.find division_id
      if division.parent_id == 1 and not division.open_date.nil?
        BranchOfBank.select(:code).where("parent_id=?", division_id).collect {|d| codes << d.code}
      else
        codes << division.code
      end
    end
    return codes
  end

  def get_joins_for_bp codes
    res = ''
    codes.each {|c|
      res = res+"join "+PLAN_OWNER+".bp_"+c+" bp"+c+" on s.id = bp"+c+".id_sprav "
    }              
    return res
  end
  
  def get_balances_plan period, division_id
    fd_ids = []
    fd_ids = get_fd_ids division_id
    
    s = "
      select sum(dfp.plan) plan
        from "+FIN_OWNER+".credit_deposit_value dfp
      where
        dfp.periods_id in
         (select p.id from "+FIN_OWNER+".periods p where p.type_period='M'
          and p.date_from between TO_DATE('"+period.start_date.to_s+"','yyyy-mm-dd') 
          and TO_DATE('"+period.end_date.to_s+"','yyyy-mm-dd'))         
        and dfp.credit_deposit_factor_id = 24 
        and dfp.sr_currency_id like '3386'
        and dfp.division_id in ("+fd_ids.join(',')+")"
    @plan = PlanDictionary.find_by_sql(s).last
    return @plan ? @plan.plan : 0
  end
  
  def get_plan_from_values period_id, division_id, factor_id
    p = Value.select('sum(factor_value) as plan').where("period_id=? and division_id=? and factor_id=? and type_id=1", period_id, division_id, factor_id).first  
    return p.plan
  end
  
  def get_delta_plan period, codes
    s_m = period.end_date.month
    e_m = s_m - 1
# bp_0* tables have mes0 collumn!
    m1 = ''
    m2 = ''
    codes.each {|c|
      m1 = m1+'bp'+c+'.mes'+s_m.to_s+'+'
      m2 = m2+'bp'+c+'.mes'+e_m.to_s+'+'
    }
    return '('+m1[0, m1.length-1]+')+('+m2[0, m2.length-1]+')'
  end
  
  def get_average_plan period, division_id, article_name
    codes = []
    codes = get_codes division_id
    sql = "
      select ("+get_delta_plan(period, codes)+")/2 as plan from "+
      PLAN_OWNER+".bp_sprav s "+ get_joins_for_bp(codes)+
      " where namepp = '"+article_name+"'"
    @plan = PlanDictionary.find_by_sql(sql).last
    return @plan ? @plan.plan : 0
    return plan    
  end
  
  def get_plan period, division_id, factor_id
    codes = []
    codes = get_codes division_id
    factor = Factor.find factor_id
# this is wery hard code!
    factor.articles.collect {|article|
      if article.action_id == 1 # plan
        if article.name == 'CONST' # return const value
          return article.source_name.to_i
        end
        if article.name == 'BALANCES'
          return get_balances_plan period, division_id
        end
        if article.name == 'get_plan_from_values'
          return get_plan_from_values period.id, division_id, factor_id
        end
        if article.name == 'get_average_plan' 
          return get_average_plan period, division_id, article.source_name
        end
        if article.name[0,2] == 'BP'  # get plan  from BP-tables
          if article.name.include?('+')
            article.name.mb_chars[article.name.index('+'),1] = "', '"
          end  
          a = "'"+article.name+"'"
          
          if article.select_type_id == 1 # sum from start year
            s = "select ("+get_months(period.start_date.beginning_of_year, period.start_date, codes)+
              ") plan from "+PLAN_OWNER+".bp_sprav s "+
              get_joins_for_bp(codes)+
              " where s.namepp in ("+a+")"
          else
            s = "select ("+get_months(period.start_date, period.end_date, codes)+
            ") plan from "+PLAN_OWNER+".bp_sprav s "+
              get_joins_for_bp(codes)+
              " where s.namepp in ("+a+")"
          end
        else
          s = build_sql_for_results period.id, codes, article.name
        end
        @plan = PlanDictionary.find_by_sql(s).last
        return @plan.plan
      end
    }
    return 0
# column_names      
#      p PlanDictionary.columns_hash.size.to_s+">>>>>>>>>>>>>>>>>>>>"
#      @fact = PlanDictionary.find_by_sql("select * from RPK880508.rezult_003 r
#        join rpk880508.directory d on d.id = r.id_directory and d.namepp = 'п00.00.05.01.00.00'").last
#      p @fact.attributes.sort.to_s+">>>>>>>>>>>>>>>>>>>>"
    
  end

  def get_months start_date, end_date, codes
    s_m = start_date.month
    e_m = end_date.month
    m_a = []
    bp_a = []
    res = 'sum('
    codes.each {|c| bp_a << 'bp'+c}
    for i in (s_m..e_m)
      m_a << 'mes'+i.to_s 
    end
    m_a.each {|m|
      bp_a.each {|b|
        res = res+b+'.'+m+'+'
      }
      res.mb_chars[res.length-1,1] = '' 
      res = res+') + sum('
    }
    return res[0, res.length-7]
  end
  
  def get_odb_division_ids division_id
    codes = []
    odb_ids = []
    codes = get_codes division_id
    codes.each {|c|
      d = Division.where("code=?", c.to_i).first
      if d
        odb_ids << d.id
      end  
    }
    return odb_ids
  end

  def get_balances_fact period, division_id 
    fd_ids = []
    fd_ids = get_fd_ids division_id
    
    s = "
      select sum(dfp.base_amount) fact
        from "+FIN_OWNER+".credit_deposit_value dfp
      where
        dfp.periods_id in
         (select p.id from "+FIN_OWNER+".periods p where p.type_period='M'
          and p.date_from between TO_DATE('"+period.start_date.to_s+"','yyyy-mm-dd') 
          and TO_DATE('"+period.end_date.to_s+"','yyyy-mm-dd'))         
        and dfp.credit_deposit_factor_id = 24 
        and dfp.sr_currency_id like '3386'
        and dfp.division_id in ("+fd_ids.join(',')+")"
    @fact = PlanDictionary.find_by_sql(s).last
    return @fact ? @fact.fact : 0
  end

  def get_fact_from_values period_id, division_id, factor_id
    f = Value.select('sum(factor_value) as fact').where("period_id=? and division_id=? and factor_id=? and type_id=2", period_id, division_id, factor_id).first  
    return f.fact
  end

  def get_fact odb_connect, odb_division_ids, factor_id, period
    
    Factor.find(factor_id).articles.collect { |a|
      if a.action_id == 2 and a.name == 'EXCLUSION' # get fin res fact from FD
        return get_fin_res_fact(period, 
          params[:report_params][:division_id], a.source_name )        
      end

      if a.action_id == 2 and a.name == 'BALANCES'
        return get_balances_fact period, params[:report_params][:division_id]
      end
      
      if a.action_id == 2 and a.name == 'get_fact_from_values' 
        return get_fact_from_values period.id, params[:report_params][:division_id], factor_id
      end  

      if a.action_id == 2 # fact
        fact = 0
        odb_division_ids.each {|division_id|
          case a.name 
            when 'get_count_transfer' then # Количество переводов за период 
              sql = " 
                declare
                  l_res number(38,2);
                begin "+
                  FACT_OWNER+".vbr_kpi.get_count_transfer(
                    TO_DATE('"+ period.start_date.beginning_of_year.to_s+"','yyyy-mm-dd'),
                    TO_DATE('"+ period.end_date.to_s+"','yyyy-mm-dd'),"+ 
                    division_id.to_s+", :l_res);  
                end; "     
            when 'get_count_municipal' then # Количество коммунальных платежей за период 
              sql = " 
                declare
                  l_res number(38,2);
                begin "+
                  FACT_OWNER+".vbr_kpi.get_count_municipal(TO_DATE('"+
                    period.start_date.beginning_of_year.to_s+"','yyyy-mm-dd'), 
                    TO_DATE('"+ period.end_date.to_s+"','yyyy-mm-dd'),"+ 
                    division_id.to_s+", :l_res);  
                end; "
            when 'get_count_depobox' then #Количество депозитарных ячеек на дату
              sql = " 
                declare
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                  l_res number(38,2);
                begin 
                  m_macro_table.extend;
                  m_macro_table(1) := "+FACT_OWNER+".T_STR_ROW('"+a.source_name+"'); "+
                  FACT_OWNER+".vbr_kpi.get_count_depobox(TO_DATE('"+ 
                    period.end_date.to_s+"','yyyy-mm-dd'),"+ 
                    division_id.to_s+", m_macro_table, :l_res); 
                end; "     
            when 'get_sum_nt_cash' then # доходы по валютообменным операциям 
              sql = "
                declare
                  l_res number(38,2);
                begin "+
                  FACT_OWNER+".vbr_kpi.get_sum_nt_cash(TO_DATE('"+
                    period.start_date.beginning_of_year.to_s+"','yyyy-mm-dd'),
                    TO_DATE('"+ period.end_date.to_s+"','yyyy-mm-dd'),"+
                    division_id.to_s+", :l_res);
                end; " 
            when 'get_count_term' then # Количество терминальных устройств на дату 
              sql = " 
                declare
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                  l_res number(38,2);
                begin
                  m_macro_table.extend;
                  m_macro_table(1) := "+FACT_OWNER+".T_STR_ROW('"+a.source_name+"'); "+
                  FACT_OWNER+".vbr_kpi.get_count_term(TO_DATE('"+
                    period.end_date.to_s+"','yyyy-mm-dd'),"+
                    division_id.to_s+", m_macro_table, :l_res);
                end; "      
            when 'get_pers_card_over' then # Процент покрытия зарплатных карт лимитами на дату 
                sql = "
                  declare
                    l_res number(38,2);
                  begin "+
                    FACT_OWNER+".vbr_kpi.get_pers_card_over(TO_DATE('"+ 
                      period.end_date.to_s+"','yyyy-mm-dd'),"+
                      division_id.to_s+", :l_res);
                  end; "
#                RAILS_DEFAULT_LOGGER.info sql+"++++++++++++++++++++++++++++"
          when 'get_count_card' then # Количество карт на дату 
              sql = "
                declare
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                  l_res number(38,2);
                begin 
                  m_macro_table.extend;
                  m_macro_table(1) := "+FACT_OWNER+".T_STR_ROW('"+a.source_name+"'); "+
                  FACT_OWNER+".vbr_kpi.get_count_card(TO_DATE('"+ 
                    period.end_date.to_s+"','yyyy-mm-dd'),"+
                    division_id.to_s+", m_macro_table, :l_res);
                end; "  
            when 'get_rest_by_ct_type' then # депозитный портфель
              sql = "
                declare
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                  l_res number(38,2);
                begin 
                  m_macro_table.extend;
                  m_macro_table(1) := "+FACT_OWNER+".T_STR_ROW('I'); "+
                  FACT_OWNER+".vbr_kpi.get_rest_by_ct_type(TO_DATE('"+ 
                    period.end_date.to_s+"','yyyy-mm-dd'),"+
                    division_id.to_s+", 'DEPOSIT_DOCUMENT', m_macro_table, l_res);
                  :l_res := l_res * (-1); 
                end; "  
                # deposite have negative value. Need * (-1)
            when 'get_pers_card_ick' then # процент охвата зарплатных карт кредитными
              sql = "
                declare
                  l_res number(38,2);
                begin "+
                  FACT_OWNER+".vbr_kpi.get_pers_card_ick(TO_DATE('"+ period.end_date.to_s+"','yyyy-mm-dd'),"+
                    division_id.to_s+", :l_res);
                end; "  
            when 'get_pers_pr_by_ct_type' then  # % проблемности  
              sql = " 
                declare
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                  l_res number(38,5);
                  p_amount_all number(38,2);
                  p_amount_expire number(38,2);
                begin "+program_names_to_array(a.source_name)+
                  FACT_OWNER+".vbr_kpi.get_pers_pr_by_ct_type(TO_DATE('"+ 
                  period.end_date.to_s+"','yyyy-mm-dd'),"+
                  division_id.to_s+",m_macro_table, :l_res, p_amount_all, p_amount_expire);
                end; "     
#              RAILS_DEFAULT_LOGGER.info sql+"++++++++++++++++++++++++++++"  
            else  # Получение суммы остатков по счету REST на дату, по отделению и по списку кодов продуктов
              sql = " 
                declare
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                  l_res number(38,2);
                begin 
                  m_macro_table.extend;
                  m_macro_table(1) := "+FACT_OWNER+".T_STR_ROW('"+a.name+"');"+
                  FACT_OWNER+".vbr_kpi.get_rest_by_ct_type(TO_DATE('"+ 
                    period.end_date.to_s+"','yyyy-mm-dd'),"+
                    division_id.to_s+",'CREDIT_DOCUMENT',m_macro_table, :l_res);
                end; "     
          end  
          if sql > ''
            plsql = odb_connect.parse(sql)
            plsql.bind_param(':l_res', nil, Float) # Fixnum 
            plsql.exec
            fact = fact+(plsql[':l_res'] ? plsql[':l_res'] : 0)
            plsql.close
          end
        }
        return fact
      end 
    }
    return 0
  end

  def get_joins_for_result codes
    res = ''
    codes.each {|c|
      res = res+"join "+PLAN_OWNER+".REZULT_"+c+" r"+c+" on d.id = r"+c+".id_directory "
    }              
    return res
  end

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
  
  def get_fact_from_result period, codes
#    .end_date.beginning_of_year, period.end_date
    res = ''
    y = period.start_date.year.to_s+"_"
    s_d = '1_1' # s_m.to_s+'_'+start_date.day.to_s
    e_d = period.end_date.month.to_s+'_'+period.end_date.day.to_s
    codes.each {|c|
      res = res + "(r"+c+".MONTH_"+y+e_d+" - r"+c+".MONTH_"+y+s_d+")+"
    }  
    return res[0,res.length-1]
  end  
  
  def get_fin_res_fact period, division_id, article
#  get fact from FD not ODB    
    codes = get_codes division_id 
    
    query = "select ("+get_fact_from_result(period, codes)+
      ") as fact from "+PLAN_OWNER+".directory d "+
      get_joins_for_result(codes)+
      "where d.namepp in ('"+article+"')"
    return PlanDictionary.find_by_sql(query).first.fact
  end
  
  def save_kpi period_id, division_id, direction_id, block_id, factor_id, 
    rate, plan, fact, percent, kpi 
    @performance = Performance.new
    @performance.period_id = period_id
    @performance.division_id = division_id
    @performance.direction_id = direction_id
    @performance.block_id = block_id
    @performance.factor_id = factor_id
    @performance.rate = rate
    @performance.plan = plan
    @performance.fact = fact
    @performance.exec_percent = percent
    @performance.kpi = kpi
    @performance.calc_date = Time.now
    @performance.save
  end
  
  def get_kpi period_id, division_id, direction_id
    @performances = Performance.where("period_id=? and division_id=? and direction_id=? and calc_date in (
      select max(calc_date) from performances where period_id=? and division_id=? and direction_id=? 
      group by factor_id order by factor_id)",
      period_id, division_id, direction_id, period_id, division_id, direction_id).order(:block_id, :factor_id)


#select id
#  from performances pf where period_id=1 and division_id=7 and direction_id=3
#and NOT EXISTS(
#  SELECT NULL FROM performances pf1
#  WHERE pf.factor_id    = pf1.factor_id
#    AND pf.calc_date    < pf1.calc_date
#    AND pf.period_id    = pf1.period_id
#    AND pf.division_id  =pf1.division_id
#    AND pf.direction_id =pf1.direction_id
#  ) 
  end
   
  def get_odb_division_id fd_division_id
    fd_division = BranchOfBank.find fd_division_id
    d = Division.where("code=?", fd_division.code.to_i).first
    return d.nil? ? 8 : d.id
  end
end

