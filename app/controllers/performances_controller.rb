# coding: utf-8
class PerformancesController < ApplicationController
  before_filter :find_direction, :only => [:get_report_division, :get_report_worker, :get_calc_division, :get_calc_worker]
  before_filter :find_period, :only => [:get_report_division, :get_report_worker, :get_calc_division, :get_calc_worker]
  PLAN_OWNER = 'RPK880508'
  FACT_OWNER = 'SR_BANK'
  FIN_OWNER  = 'FIN'
  def index
    @performances = Performance.order(:period_id, :direction_id, :division_id, :block_id, :factor_id)
  end

  def show_values
    if Direction.find(params[:direction_id]).level_id == 4
    @values = Performance.where('division_id=? and direction_id=? and factor_id=?  and employee_id=? and calc_date in(
      select max(calc_date) from performances where division_id=? and direction_id=? and factor_id=? and employee_id=? 
      group by period_id order by period_id)',params[:division_id], params[:direction_id], params[:factor_id], params[:worker_id],
      params[:division_id], params[:direction_id], params[:factor_id], params[:worker_id]).order(:period_id)   
    else
      @values = Performance.where('division_id=? and direction_id=? and factor_id=? and calc_date in(
      select max(calc_date) from performances where division_id=? and direction_id=? and factor_id=? 
      group by period_id order by period_id)',params[:division_id], params[:direction_id], params[:factor_id],
      params[:division_id], params[:direction_id], params[:factor_id]).order(:period_id)
    end  
  end
  
  def show_kpi_by_divisions
    @values = Performance.where('period_id=? and direction_id=? and factor_id=? and calc_date in(
      select max(calc_date) from performances where period_id=? and direction_id=? and factor_id=? 
      group by division_id order by division_id)',params[:period_id], params[:direction_id], params[:factor_id],
      params[:period_id], params[:direction_id], params[:factor_id]) #.order(:division_id)   
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

  def get_calc_division
  end
  
  def get_calc_params_2
    direction = Direction.find params[:report_params][:direction_id]
    case direction.level_id 
      when 1 then # whole the bank
        redirect_to :action => :calc_kpi, 
                    :report_params => {:division_id =>  '999'}, 
                    :period_id => params[:report_params][:period_id],
                    :direction_id => direction.id
      when 4 then # by worker
        redirect_to :action => :calc_kpi, 
                    :report_params => {:division_id =>  '1002'}, 
                    :period_id => params[:report_params][:period_id],
                    :direction_id => direction.id
#        redirect_to :action => :get_calc_worker, 
#                    :period_id => params[:report_params][:period_id],
#                    :direction_id => direction.id                             
      else # divisions and regions
        redirect_to :action => :get_calc_division, 
                    :direction_id => direction.id, 
                    :period_id => params[:report_params][:period_id]
    end
  end
  
  def get_calc_worker
  end
  
  def get_calc_params
  end
  
  def calc_kpi
    period = Period.find(params[:period_id])
    direction = Direction.find params[:direction_id]
    odb_connection = OCI8.new("kpi", "MVM55010101", "srbank")
#    if params[:report_params][:worker_id]
#      w = Worker.select('code_division, lastname, firstname, soname').where('id_emp=?',params[:report_params][:worker_id]).first
#      fullname = w.lastname.to_utf+' '+w.firstname.to_utf+' '+w.soname.to_utf
#      code_division = w.code_division[0,3]
#      d = BranchOfBank.where("code = ?",code_division).first
#      fd_division_id = d.id
#      worker_id = params[:report_params][:worker_id]
    if params[:report_params][:division_id] == '1002' # calc all workers
      @workers = Worker.find_by_sql(" select e.id_emp id, e.tabn, e.code_division, 
        e.lastname lastname, e.firstname firstname, e.soname soname, 
        p.division parent from emp2doc e 
        join div2doc d on d.id_division = e.id_division 
        join div2doc p on p.id_division = d.parent_id 
        where e.code_division like '%8000' and e.code_division > '0009999' 
        order by p.code_division")
        
      calc_kpi_for_all_divisions period, direction, odb_connection
      redirect_to :action       => :get_report_worker, 
                  :period_id    => params[:period_id],
                  :direction_id => params[:direction_id] 
#      redirect_to :action => 'get_report_division', :direction_id => params[:direction_id], :period_id => params[:period_id]  
      return
    else
      if params[:report_params][:division_id] == '1001' # calc all divisions
        calc_kpi_for_all_divisions period, direction, odb_connection
        redirect_to :action => 'get_report_division', :direction_id => params[:direction_id], :period_id => params[:period_id]  
        return
      end
      fd_division_id = params[:report_params][:division_id]
      worker_id = 0
      fullname = ''
    end
    
    odb_division_ids = []
    odb_division_ids = get_odb_division_ids fd_division_id 
    for b in direction.blocks do  
      for f in b.factors do
        if f.factor_weights.last.weight > 0.00001
          plan = get_plan period, fd_division_id, f.id, worker_id
          plan = plan ? plan : 0
          fact = get_fact odb_connection, odb_division_ids, f.id, period, fd_division_id, worker_id
          fact = (fact ? fact : 0)
          bw = b.block_weights.last
          fw = f.factor_weights.last
          rate = bw.weight * fw.weight
          percent = 0
          if f.factor_description.short_name == "% проблемности" 
            if fact > 0
              percent = get_problem_percent(f.id, fact)
            end
          else
            percent = ((plan and (plan != 0))  ? 100*fact.to_f/plan.to_f : 0)
          end
          percent = 200 if percent > 200
          
          kpi = rate*percent
         
          save_kpi period.id, fd_division_id, direction.id,
            b.id, f.id, worker_id, fullname, rate, plan, fact, percent, kpi
        end
      end
    end
    odb_connection.logoff
    redirect_to :action => :show_report, 
      :report_params => {:period_id => params[:period_id], 
      :division_id =>  fd_division_id, 
      :direction_id => params[:direction_id]}
  end
    
  def show_report
    if params[:report_params][:worker_id]
      w = Worker.select('code_division, lastname, firstname, soname').
#        find_by_id_emp params[:report_params][:worker_id]
        where('id_emp=?',params[:report_params][:worker_id]).first
#      fullname = w.lastname.to_utf+' '+w.firstname.to_utf+' '+w.soname.to_utf
      code_division = w.code_division[0,3]
      d = BranchOfBank.where("code = ?",code_division).first
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
  
  private

  def get_problem_percent factor_id, argument
    pr = ProblemRate.select(:result_value).
      where('? between begin_value and stop_value and factor_id=?', argument, factor_id).
      order(:start_date).last
    return pr ? pr.result_value : 0  
  end
  
  def get_plans start_date, end_date, codes
#    s_m = start_date.month
#    e_m = end_date.month
    res = ''
    codes.each {|c|
#      al = 'r'+c
      for i in start_date.month..end_date.month
        res = res+'r'+c+'.plan_'+i.to_s+'+'
      end
    }
    return res[0, res.length-1]
  end

  def get_plan_fin_res_2 period, codes, article
    query =
      "select id from "+PLAN_OWNER+".directory d where d.namepp in ("+article+")"
    article_id = PlanDictionary.find_by_sql(query).last.id
    query = ''
    query = "select ("+get_plans(period.start_date.beginning_of_year, period.end_date, codes)+
      ") as plan from "+make_from(codes)+
      " where "+make_where(codes, article_id.to_s)
    return PlanDictionary.find_by_sql(query).last.plan
  end

  def build_sql_for_results period_id, codes, article_name 
    p = Period.find(period_id)

    return  "select ("+get_plans(p.start_date.beginning_of_year, p.end_date, codes)+
      ") as plan from "+PLAN_OWNER+".directory d "+
      get_joins_for_result(codes)+
      " where d.namepp in ("+article_name+")"    
  end

  def get_fd_ids division_id
    fd_ids = []
    if division_id == '999' #'1' # whole the bank
      BranchOfBank.select(:id).where("open_date is not null").collect { 
        |d| fd_ids << d.id
      }  
    else
      division = BranchOfBank.find division_id
      if division.parent_id == 1 and not division.open_date.nil?
        BranchOfBank.select(:id).where("parent_id=? and open_date is not null", division_id).collect {|d| fd_ids << d.id}
      else
        fd_ids << division.id
      end
    end
    return fd_ids
  end

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

  def get_joins_for_bp codes
    res = ''
    codes.each {|c|
      res = res+" join "+PLAN_OWNER+".bp_"+c+" bp"+c+" on s.id = bp"+c+".id_sprav "
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
  
  def get_plan_from_values_by_worker period_id, worker_id, factor_id
    p = Value.select('sum(factor_value) as plan').
      where("period_id=? and worker_id=? and factor_id=? and type_id=1", period_id, worker_id, factor_id).first  
    return p.plan
  end
  
  def collect_plan_from_values_by_workers period_id, division_id, collect_factor_id
    p = Value.select('sum(factor_value) as plan').where("period_id=? and division_id=? and factor_id=? and type_id=1", period_id, division_id, collect_factor_id).first  
    return p.plan
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
      " where namepp = "+article_name
    @plan = PlanDictionary.find_by_sql(sql).last
    return @plan ? @plan.plan : 0
    return plan    
  end

  def get_plan_average_new period, codes, article
    m = period.end_date.month-1
    query = "
      select (v.mes"+period.end_date.month.to_s+"+v.mes"+m.to_s+")/2 as plan from
        fin.factor f, /*справочник*/
        fin.bud_value v, /*значения*/
        fin.bud_prefix p, /*период расчета*/
        fin.division d
        where f.id = v.factor_id(+)
          and v.bud_prefix_id = p.id
          and p.id = 4 /*с учетом всех корректировок*/ 
          and f.code in ("+article+")
          and v.division_id = d.id
          and d.code in ("+codes.join(',')+")"    
    p = PlanDictionary.find_by_sql(query).last
    return p.plan
  end
  
  
  def get_plan_from_bp_new period, codes, article
    query = "  
      select sum(v.mes"+period.end_date.month.to_s+") plan from
      fin.factor f, /*справочник*/
      fin.bud_value v, /*значения*/
      fin.bud_prefix p, /*период расчета*/
      fin.division d
      where f.id = v.factor_id(+)
        and v.bud_prefix_id = p.id
        and p.id = 4 /*с учетом всех корректировок*/ 
        and f.code in ("+article+")
        and v.division_id = d.id
        and d.code in ("+codes.join(',')+")" 
    p = PlanDictionary.find_by_sql(query).last
    return p.plan
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
   
  def get_plan_from_bp_new_by_interval start_date, end_date, codes, article
    query ="
      select "+make_fields_list(start_date, end_date)+" plan from
         fin.factor f,
         fin.bud_value v,
         fin.bud_prefix p,
         fin.division d
       where f.id = v.factor_id(+)
         and v.bud_prefix_id = p.id
         and p.id = 4 
         and f.code in ("+article+")
         and v.division_id = d.id
         and d.code in ("+codes.join(',')+")"
    p = PlanDictionary.find_by_sql(query).last
    return p.plan
  end
  
  def get_plan_rest_average_curr_accounts start_date, codes
    query ="
      select sum(dfp.plan) as plan
        from "+FIN_OWNER+".credit_deposit_value dfp
        where dfp.periods_id in
          (select p.id from "+FIN_OWNER+".periods p where p.type_period='M'
           and p.date_from = TO_DATE('"+start_date.to_s+"','yyyy-mm-dd'))
           and dfp.credit_deposit_factor_id = 23
           and dfp.division_id in (SELECT d.id FROM "+FIN_OWNER+".division d
          where d.fact=1 and d.code in ("+codes.join(',')+"))"
           
    p = PlanDictionary.find_by_sql(query).last
    return p.plan
  end  

  def get_plan_over_average codes, factor_id, period_id
    business = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor_id, 11).last.value
    query = "
      select sum(dfp.plan) plan
        from "+FIN_OWNER+".credit_deposit_value dfp,
          (SELECT ID FROM "+FIN_OWNER+".credit_deposit_factor t
            CONNECT BY PRIOR t.ID = t.PARENT_ID START WITH id =25) tree,
          (SELECT d.id FROM "+FIN_OWNER+".division d
                where d.fact=1 and d.code in ("+codes.join(',')+")) div
        where 
          dfp.sr_busines_id like (select id from "+FIN_OWNER+".sr_busines where code = '"+business+"')
          and dfp.division_id = div.id
          and dfp.credit_deposit_factor_id =tree.id
          and dfp.periods_id="+period_id.to_s
    p = PlanDictionary.find_by_sql(query).last
    return p.plan
  end
  
  def get_plan period, division_id, factor_id, worker_id
    codes = []
    codes = get_codes division_id
    factor = Factor.find factor_id
    if (not factor.plan_descriptor.nil?) and factor.plan_descriptor > ''
      case factor.plan_descriptor
        when 'get_plan_over_average'
          return get_plan_over_average codes, factor_id, period.id
        when 'get_plan_rest_average_curr_accounts'
          return get_plan_rest_average_curr_accounts period.start_date, codes
        when 'get_plan_fin_res'
          article = Param.where('factor_id=? and action_id=1 and param_description_id=?', factor.id, 5).last.value
          return get_plan_fin_res_2 period, codes, article
        when 'get_plan_from_bp_new'
          article = Param.where('factor_id=? and action_id=1 and param_description_id=?', factor.id, 4).last.value
          return get_plan_from_bp_new period, codes, article
        when 'get_plan_from_bp_new_by_begin_year'
          article = Param.where('factor_id=? and action_id=1 and param_description_id=?', factor.id, 4).last.value
          return get_plan_from_bp_new_by_interval period.start_date.beginning_of_year, period.end_date, codes, article
        when 'get_plan_from_bp'  
          article = Param.where('factor_id=? and action_id=1 and param_description_id=?', factor.id, 4).last.value
          query = "select ("+get_months(period.start_date, period.end_date, codes)+
            ") plan from "+PLAN_OWNER+".bp_sprav s "+
              get_joins_for_bp(codes)+
              " where s.namepp in ("+article+")"
          @plan = PlanDictionary.find_by_sql(query).last
          return @plan.plan
        when 'get_plan_const'  
          return Param.where('factor_id=? and action_id=1 and param_description_id=?', factor.id, 8).last.value.to_i
        when 'get_plan_from_values_by_worker'
          return get_plan_from_values_by_worker period.id, worker_id, factor_id
        when 'collect_plan_from_values_by_workers'
          article = Param.where('factor_id=? and action_id=1 and param_description_id=?', factor.id, 9).last.value
          return collect_plan_from_values_by_workers period.id, division_id, article
        when 'get_plan_average'
          article = Param.where('factor_id=? and action_id=1 and param_description_id=?', factor.id, 4).last.value
          return get_average_plan period, division_id, article
        when 'get_plan_average_new'
          article = Param.where('factor_id=? and action_id=1 and param_description_id=?', factor.id, 4).last.value
          return get_plan_average_new period, codes, article
        when 'get_plan_from_values'
          return get_plan_from_values period.id, division_id, factor_id
        when 'get_plan_fin_res_by_divisions'
          article = Param.where('factor_id=? and action_id=1 and param_description_id=?', factor.id, 5).last.value
          codes = Fixation.where("master_id=?", worker_id).last.addition.split(',')
          query = build_sql_for_results period.id, codes, article
          @plan = PlanDictionary.find_by_sql(query).last
          return @plan.plan
        when 'get_plan_balances'
          return get_balances_plan period, division_id
        when 'get_plan_from_res'  
          codes = get_codes division_id
          article = Param.where('factor_id=? and action_id=1 and param_description_id=?', factor.id, 5).last.value
          query =  "select ("+get_plans(period.end_date, period.end_date, codes)+
            ") as plan from "+PLAN_OWNER+".directory d "+
            get_joins_for_result(codes)+
            " where d.namepp in ("+article+")"
          @plan = PlanDictionary.find_by_sql(query).last
          return @plan.plan
      end    
    end
    return 0
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
# need divide 000 and 002    
    is_go = false
    codes.each {|c|
      if not(is_go and (c == '000' or c == '002'))
        d = Division.find_by_code ((c == '000' or c == '002') ? 1 : c.to_i)
        if d
          odb_ids << d.id
        end  
      end
      if c == '000' or c == '002'
        is_go = true
      end 
    }
    return odb_ids
  end

  def get_balances_fact period, division_id 
    fd_ids = []
    fd_ids = get_fd_ids division_id
    s = ''
    if division_id.to_i != 1
      s = " and dfp.division_id in ("+fd_ids.join(',')+")"
    end
    query = "
      select sum(dfp.base_amount) fact
        from "+FIN_OWNER+".credit_deposit_value dfp
      where
        dfp.periods_id in
         (select p.id from "+FIN_OWNER+".periods p where p.type_period='M'
          and p.date_from between TO_DATE('"+period.start_date.to_s+"','yyyy-mm-dd') 
          and TO_DATE('"+period.end_date.to_s+"','yyyy-mm-dd'))         
        and dfp.credit_deposit_factor_id = 24 "+s 
        
#               RAILS_DEFAULT_LOGGER.info query+"+++++++++++++++++++++"        
    f = PlanDictionary.find_by_sql(query).last
    return f ? f.fact : 0
  end

  def get_fact_from_values period_id, division_id, factor_id
    f = Value.select('sum(factor_value) as fact').where("period_id=? and division_id=? and factor_id=? and type_id=2", period_id, division_id, factor_id).first  
    return f.fact
  end

  def get_fact_over period_id, fd_division_id, factor_id
    codes = []
    codes = get_codes fd_division_id
    businnes_code = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor_id, 11).last.value
    query = "
      select abs(sum(dfp.base_amount)) as base_amount_all
        from "+FIN_OWNER+".credit_deposit_value dfp,
          (SELECT ID FROM "+FIN_OWNER+".credit_deposit_factor t
            CONNECT BY PRIOR t.ID = t.PARENT_ID START WITH id =25) tree,
          (SELECT d.id, d.name, d.code FROM "+FIN_OWNER+".division d
                where d.fact=1 and d.code in ("+codes.join(',')+")) div
        where  dfp.sr_busines_id like (select id from "+FIN_OWNER+".sr_busines where code = '"+businnes_code+"')
          and dfp.division_id = div.id
          and dfp.credit_deposit_factor_id =tree.id
          and dfp.periods_id="+period_id.to_s
    fact = PlanDictionary.find_by_sql(query).last
    return fact.base_amount_all   
  end
  
  def get_codes_divisions_as_str division_id
    codes = []
    codes = get_codes division_id
    return codes.join(',')
  end
  
  def get_fact_deposit_by_day fd_division_id, period, factor_id
    businnes_code = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor_id, 11).last.value
    if fd_division_id.to_i == 1
     if businnes_code == 'I'
       s = " where dfp.division_id != 1 and "
     else
       s = " where "
     end
    else  
      s = ", (SELECT d.id, d.name, d.code FROM "+FIN_OWNER+".division d
          where d.fact=1 and d.code in ("+get_codes_divisions_as_str(fd_division_id)+")) div
        where dfp.division_id = div.id and "
    end
    
    query = "
      select abs(sum(dfp.base_amount)) as base_amount_all
        from "+FIN_OWNER+".credit_deposit_value dfp,
        (SELECT ID FROM FIN.credit_deposit_factor t
          CONNECT BY PRIOR t.ID = t.PARENT_ID START WITH id =15) tree"+s+"
          dfp.sr_busines_id like (select id from "+FIN_OWNER+".sr_busines where code = '"+businnes_code+"')
          and dfp.credit_deposit_factor_id =tree.id
          and dfp.periods_id=(select id from fin.periods where date_from = TO_DATE('"+
          period.end_date.to_s+"','yyyy-mm-dd'))"
    fact = PlanDictionary.find_by_sql(query).last
    return fact.base_amount_all   
  end
  
  def get_fact_current_accounts fd_division_id, period_id, factor_id
    if fd_division_id == 1
      s = " where "
    else  
      s = ", (SELECT d.id, d.name, d.code FROM "+FIN_OWNER+".division d
          where d.fact=1 and d.code in ("+get_codes_divisions_as_str(fd_division_id)+")) div
        where dfp.division_id = div.id and "
    end
    businnes_code = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor_id, 11).last.value
    query = "
      select abs(sum(dfp.base_amount)) as base_amount_all
        from "+FIN_OWNER+".credit_deposit_value dfp,
    (SELECT ID FROM "+FIN_OWNER+".credit_deposit_factor t
      CONNECT BY PRIOR t.ID = t.PARENT_ID START WITH id =20) tree"+s+" 
    dfp.sr_busines_id like (select id from "+FIN_OWNER+".sr_busines where code = '"+businnes_code+"')
    and dfp.credit_deposit_factor_id =tree.id
    and dfp.periods_id="+period_id.to_s    
    fact = PlanDictionary.find_by_sql(query).last
    return fact.base_amount_all   
  end
  
  def get_selected_fields start_date, end_date, codes
    res = ''
    s_y = start_date.year.to_s+"_"
    e_y = end_date.year.to_s+"_"
    s_d = start_date.month.to_s+'_'+start_date.day.to_s
    e_d = end_date.month.to_s+'_'+end_date.day.to_s
    codes.each {|c|
      res = res + "(r"+c+".MONTH_"+e_y+e_d+" - r"+c+".MONTH_"+s_y+s_d+")+"
    }  
    return res[0,res.length-1]
  end    
  
  def get_fact_from_res_by_interval fd_division_id, period, factor_id
    codes = get_codes fd_division_id
    article = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor_id, 5).last.value
    end_date = period.end_date
    start_date = period.start_date.prev_month.end_of_month
    query = "select ("+get_selected_fields(start_date, end_date, codes)+
      ") as fact from "+PLAN_OWNER+".directory d "+
      get_joins_for_result(codes)+
      " where d.namepp in ("+article+")"
    return PlanDictionary.find_by_sql(query).first.fact
  end
  
  def get_fact_credit_value period, factor_id, codes 
    business = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor_id, 11).last.value
    query = "
      select sum(dfp.base_amount) fact
        from "+FIN_OWNER+".credit_deposit_value dfp, "+FIN_OWNER+".division d
        where dfp.periods_id=(select id from "+FIN_OWNER+
          ".periods where date_from = TO_DATE('"+period.end_date.to_s+"','yyyy-mm-dd'))
          and dfp.credit_deposit_factor_id = (
            select id from "+FIN_OWNER+".credit_deposit_factor
              where parent_id = 1 and sr_busines_id =
                (select id from "+FIN_OWNER+".sr_busines where code = '"+business+"'))                    
          and dfp.division_id = d.id 
          and d.code in ("+codes.join(',')+")"    
    f = PlanDictionary.find_by_sql(query).last
    return f.fact   
  end
  
  def get_fact_credit_value_msb period, codes
    query = "
      select sum(dfp.base_amount) fact
        from "+FIN_OWNER+".credit_deposit_value dfp, "+FIN_OWNER+".division d
        where dfp.periods_id=(select id from "+FIN_OWNER+
          ".periods where date_from = TO_DATE('"+period.end_date.to_s+"','yyyy-mm-dd'))
          and dfp.credit_deposit_factor_id = 11
          and dfp.division_id = d.id
          and d.code in ("+codes.join(',')+")"
    f = PlanDictionary.find_by_sql(query).last
    return f.fact   
  end
  
# RAILS_DEFAULT_LOGGER.info query+"++++++++++++++++++++++++++++"       
  
  def get_fact odb_connect, odb_division_ids, factor_id, period, fd_division_id, worker_id
    factor = Factor.find factor_id
    level_id = factor.block.direction.level_id
    if (not factor.fact_descriptor.nil?) and factor.fact_descriptor > ''
      if factor.fact_descriptor == 'get_fact_credit_value_msb'
        codes = get_codes fd_division_id 
        return get_fact_credit_value_msb period, codes
      end
      if factor.fact_descriptor == 'get_fact_credit_value'
        codes = get_codes fd_division_id
        return get_fact_credit_value period, factor_id, codes
      end
      if factor.fact_descriptor == 'get_fact_fin_res'
        codes = get_codes fd_division_id 
        article = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 5).last.value
        return get_fact_fin_res_2 period, codes, article
      end
      if factor.fact_descriptor == 'get_fact_fin_res_by_divisions'
        codes = Fixation.where("master_id=?", worker_id).last.addition.split(',')
        article = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 5).last.value
        return get_fact_fin_res period, codes, article
      end
      if factor.fact_descriptor == 'get_fact_from_values'
        return get_fact_from_values period.id, fd_division_id, factor_id    
      end
      if factor.fact_descriptor == 'get_fact_balances'
        return get_balances_fact period, fd_division_id    
      end
      if factor.fact_descriptor == 'get_fact_over_average'
        return get_fact_over period.id, fd_division_id, factor_id
      end
      if factor.fact_descriptor == 'get_fact_deposit'
        return get_fact_deposit_by_day fd_division_id, period, factor_id
      end
      if factor.fact_descriptor == 'get_fact_current_accounts'
        return get_fact_current_accounts fd_division_id, period.id, factor_id
      end
      if factor.fact_descriptor == 'get_fact_from_res_by_interval'
        return get_fact_from_res_by_interval fd_division_id, period, factor_id
      end
      
      if (factor.fact_descriptor == 'get_fact_from_rest_by_program') or (factor.fact_descriptor == 'get_fact_from_rest')
        program_names = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 6).last.value
        s = ' true '
        if level_id > 1
          s = "division_id in ("+odb_division_ids.join(',')+")"
        end
        query = "
        declare
          c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
          division_id pls_integer; 
          amount number(38,2);
          amount2 number(38,2);
          l_res number(38,2);
          m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
        begin "+program_names_to_array(program_names)+
          FACT_OWNER+".vbr_kpi.get_rest_by_ct_type(TO_DATE('"+ 
          period.end_date.to_s+"','yyyy-mm-dd'), 
          'CREDIT_DOCUMENT', 'F', m_macro_table, c_cursor);
         
          l_res := 0;
          FETCH c_cursor INTO division_id, amount, amount2;
          LOOP
            if "+s+" then 
              if amount is not null then
                l_res := l_res + amount;
              end if;        
              if amount2 is not null then
                l_res := l_res + amount2;
              end if;        
            end if;
            FETCH c_cursor INTO division_id, amount, amount2;
            EXIT WHEN c_cursor%NOTFOUND;
          END LOOP;
          :l_res := l_res;
        end;"
#                RAILS_DEFAULT_LOGGER.info query+"++++++++++++++++++++++++++++"
        
        return get_fact_from_odb odb_connect, query
      end
      if factor.fact_descriptor == 'get_fact_municipal_by_contract'
#            contract_ids = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 12).last.value
            s = 'true'
            if level_id > 1 
              s = " division_id in ("+odb_division_ids.join(',')+") "
            end
            query = "
              declare
                c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                division_id pls_integer; 
                contract_id pls_integer;
                count_payment pls_integer;
                count_payment2 pls_integer;
                l_res number(38,2);
              begin
                "+FACT_OWNER+".vbr_kpi.get_count_municipal(TO_DATE('"+
                period.start_date.beginning_of_year.to_s+"','yyyy-mm-dd'),
                TO_DATE('"+ period.end_date.to_s+"','yyyy-mm-dd'), c_cursor);
                l_res := 0;
                FETCH c_cursor INTO division_id, contract_id, count_payment, count_payment2;
                LOOP
                  if "+s+" then
                    if contract_id in (0, 23961) then
                      l_res := l_res + count_payment;
                    end if;  
                    if contract_id = 24991 then
                      l_res := l_res + count_payment2;
                    end if;  
                  end if;
                  FETCH c_cursor INTO division_id, contract_id, count_payment, count_payment2;
                  EXIT WHEN c_cursor%NOTFOUND;
                END LOOP;
                :l_res := l_res;
              end;"            
                
#                  if "+s+" contract_id in ("+contract_ids+") then
#                    if contract_id = 24991 then
#                      l_res := l_res + count_payment2;
#                    else  
#                      l_res := l_res + count_payment;
#                    end if;
#                  end if;             
#         case when mp.contract_id in
#         (17608,  -- ПКТС
#          12205,  -- ЕРЦ
#          24991,  -- флэш-киоск
#          10990,  -- пополнения моб. операторов
#          23961)  -- СДА             
#                RAILS_DEFAULT_LOGGER.info Time.now.to_s+ "++++++++++++time1++++++++++++++++"
        return get_fact_from_odb odb_connect, query
      end
      if factor.fact_descriptor == 'get_fact_transfer'
        s = ' true '
        if level_id > 1
          s = "division_id in ("+odb_division_ids.join(',')+")"
        end
        query = " 
          declare
            c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
            division_id pls_integer; 
            amount pls_integer;
            l_res number(38,2);
          begin "+
            FACT_OWNER+".vbr_kpi.get_count_transfer(TO_DATE('"+ 
            period.start_date.beginning_of_year.to_s+
            "','yyyy-mm-dd'), TO_DATE('"+ period.end_date.to_s+"','yyyy-mm-dd'), c_cursor); 
            l_res := 0;
            FETCH c_cursor INTO division_id, amount;
            LOOP
              if "+s+" then 
                if amount is not null then
                  l_res := l_res + amount;
                end if;        
              end if;
              FETCH c_cursor INTO division_id, amount;
              EXIT WHEN c_cursor%NOTFOUND;
            END LOOP;
            :l_res := l_res;
          end; "
        return get_fact_from_odb odb_connect, query
      end
      if factor.fact_descriptor == 'get_fact_card_count'
        program_names = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 6).last.value
        s = ' true '
        if level_id > 1
          s = "division_id in ("+odb_division_ids.join(',')+")"
        end
        query = " 
          declare
            c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
            division_id pls_integer; 
            amount pls_integer;
            m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
            l_res number(38,2);
          begin "+program_names_to_array(program_names)+
            FACT_OWNER+".vbr_kpi.get_count_card(TO_DATE('"+ 
            period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, c_cursor); 
            l_res := 0;
            FETCH c_cursor INTO division_id, amount;
            LOOP
              if "+s+" then 
                if amount is not null then
                  l_res := l_res + amount;
                end if;        
              end if;
              FETCH c_cursor INTO division_id, amount;
              EXIT WHEN c_cursor%NOTFOUND;
            END LOOP;
            :l_res := l_res;
          end; "  
        return get_fact_from_odb odb_connect, query
      end
      if factor.fact_descriptor == 'get_count_term' # Количество терминальных устройств на дату
        terminal_type = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 10).last.value
        s = ' true '
        if level_id > 1
          s = "division_id in ("+odb_division_ids.join(',')+")"
        end
        query = " 
          declare
            c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
            division_id pls_integer; 
            amount pls_integer;
            m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
            l_res number(38,2);
          begin "+program_names_to_array(terminal_type)+
            FACT_OWNER+".vbr_kpi.get_count_term(TO_DATE('"+
              period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, c_cursor); 
            l_res := 0;
            FETCH c_cursor INTO division_id, amount;
            LOOP
              if "+s+" then 
                if amount is not null then
                  l_res := l_res + amount;
                end if;        
              end if;
              FETCH c_cursor INTO division_id, amount;
              EXIT WHEN c_cursor%NOTFOUND;
            END LOOP;
            :l_res := l_res;
          end; "     
        return get_fact_from_odb odb_connect, query
      end
      if factor.fact_descriptor == 'get_fact_depobox' 
        program_names = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 6).last.value
        s = ' true '
        if level_id > 1
          s = "division_id in ("+odb_division_ids.join(',')+")"
        end
        query = " 
          declare
            c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
            division_id pls_integer; 
            amount pls_integer;
            m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
            l_res number(38,2);
          begin "+program_names_to_array(program_names)+
            FACT_OWNER+".vbr_kpi.get_count_depobox(TO_DATE('"+ 
            period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, c_cursor); 
            l_res := 0;
            FETCH c_cursor INTO division_id, amount;
            LOOP
              if "+s+" then 
                if amount is not null then
                  l_res := l_res + amount;
                end if;        
              end if;
              FETCH c_cursor INTO division_id, amount;
              EXIT WHEN c_cursor%NOTFOUND;
            END LOOP;
            :l_res := l_res; 
          end; "     
        return get_fact_from_odb odb_connect, query
      end
      if factor.fact_descriptor == 'get_fact_open_accounts' 
        program_names = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 6).last.value
        s = ' true '
        if level_id > 1
          s = "division_id in ("+odb_division_ids.join(',')+")"
        end
        query = " 
          declare
            c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
            division_id pls_integer; 
            m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
            l_res pls_integer;
            amount pls_integer;
            res_client_bank pls_integer; 
            res_gsm pls_integer;
            res_active pls_integer;
          begin "+program_names_to_array(program_names)+
            FACT_OWNER+".vbr_kpi.get_count_tariff(TO_DATE('"+ 
            period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, c_cursor); 
            l_res := 0;
            FETCH c_cursor INTO division_id, amount, res_client_bank, res_gsm, res_active;
            LOOP
              if "+s+" then 
                if amount is not null then
                  l_res := l_res + amount;
                end if;        
              end if;
              FETCH c_cursor INTO division_id, amount, res_client_bank, res_gsm, res_active;
              EXIT WHEN c_cursor%NOTFOUND;
            END LOOP;
            :l_res := l_res; 
          end; "
        plsql = odb_connect.parse(query)
        plsql.bind_param(':l_res', nil, Fixnum)
        plsql.exec
        fact = plsql[':l_res'] ? plsql[':l_res'] : 0
        plsql.close
        return fact
      end
      if factor.fact_descriptor == 'get_fact_percent_accounts_active' 
        s = ' true '
        if level_id > 1
          s = "division_id in ("+odb_division_ids.join(',')+")"
        end
        query = "
          declare
            c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
            division_id pls_integer; 
            m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
            l_accounts pls_integer;
            l_client_bank pls_integer;
            l_gsm_banking pls_integer;
            l_actives pls_integer;
            l_acc pls_integer;
            l_act pls_integer;
            l_res pls_integer;
          begin 
            m_macro_table.extend;
            m_macro_table(1) := "+FACT_OWNER+".T_STR_ROW('KSTG'); "+
            FACT_OWNER+".vbr_kpi.get_count_tariff(TO_DATE('"+
            period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, c_cursor);
            l_acc := 0;
            l_act := 0;
            FETCH c_cursor INTO division_id, l_accounts, l_client_bank, l_gsm_banking, l_actives;
            LOOP
              if "+s+" then 
                if l_accounts is not null then
                  l_acc := l_acc + l_accounts;
                end if;
                if l_actives is not null then
                  l_act := l_act + l_actives;  
                end if;    
              end if;
              FETCH c_cursor INTO division_id, l_accounts, l_client_bank, l_gsm_banking, l_actives;
              EXIT WHEN c_cursor%NOTFOUND;
            END LOOP;
            :l_res := 0;
            if l_acc > 0 then
              :l_res := l_act*100/l_acc;
            end if;   
          end; "
        return get_fact_from_odb odb_connect, query
      end
      if factor.fact_descriptor == 'get_fact_percent_kb_servises_using' 
        s = ' true '
        if level_id > 1
          s = "division_id in ("+odb_division_ids.join(',')+")"
        end
        query = "
          declare
            c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
            division_id pls_integer; 
            m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
            l_accounts pls_integer;
            l_client_bank pls_integer;
            l_gsm_banking pls_integer;
            l_actives pls_integer;
            l_acc pls_integer;
            l_srv pls_integer;
            l_res pls_integer;
          begin 
            m_macro_table.extend;
            m_macro_table(1) := "+FACT_OWNER+".T_STR_ROW('KSTG'); "+
            FACT_OWNER+".vbr_kpi.get_count_tariff(TO_DATE('"+
            period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, c_cursor);
            l_acc := 0;
            l_srv := 0;
            FETCH c_cursor INTO division_id, l_accounts, l_client_bank, l_gsm_banking, l_actives;
            LOOP
              if "+s+" then 
                if l_accounts is not null then
                  l_acc := l_acc + l_accounts;
                end if;
                if l_client_bank is not null then
                  l_srv := l_srv + l_client_bank;
                end if;
                if l_gsm_banking is not null then
                  l_srv := l_srv + l_gsm_banking;   
                end if;   
              end if;
              FETCH c_cursor INTO division_id, l_accounts, l_client_bank, l_gsm_banking, l_actives;
              EXIT WHEN c_cursor%NOTFOUND;
            END LOOP;
            :l_res := 0;
            if l_acc > 0 then
              :l_res := l_srv*100/l_acc;
            end if;
          end; "
        return get_fact_from_odb odb_connect, query
      end
      if factor.fact_descriptor == 'get_fact_card_ick' # процент охвата зарплатных карт кредитными 
        s = ' true '
        if level_id > 1
          s = "division_id in ("+odb_division_ids.join(',')+")"
        end
        query = " 
          declare
            c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
            division_id pls_integer; 
            cards pls_integer;
            overs pls_integer;
            l_card pls_integer;
            l_over pls_integer;
            l_res number(38,2);
          begin "+
            FACT_OWNER+".vbr_kpi.get_pers_card_ick(TO_DATE('"+ period.end_date.to_s+"','yyyy-mm-dd'),c_cursor);
            l_card := 0;
            l_over := 0;
            FETCH c_cursor INTO division_id, overs, cards;
            LOOP
              if "+s+" then 
                if cards is not null then
                  l_card := l_card + cards;
                end if;
                if overs is not null then
                  l_over := l_over + overs;
                end if;
              end if;
              FETCH c_cursor INTO division_id, overs, cards;
              EXIT WHEN c_cursor%NOTFOUND;
            END LOOP;
            :l_res := 0;
            if l_card > 0 then
              :l_res := l_over*100/l_card;
            end if;
          end; "  
        return get_fact_from_odb odb_connect, query
      end
      if factor.fact_descriptor == 'get_fact_card_over'  
        s = ' true '
        if level_id > 1
          s = "division_id in ("+odb_division_ids.join(',')+")"
        end
        program_names = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 6).last.value
        query = " 
          declare
            m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
            c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
            division_id pls_integer; 
            cards pls_integer;
            overs pls_integer;
            l_card pls_integer;
            l_over pls_integer;
            l_res number(38,2);
          begin "+program_names_to_array(program_names)+
            FACT_OWNER+".vbr_kpi.get_pers_card_over(TO_DATE('"+ 
            period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, c_cursor);
            l_card := 0;
            l_over := 0;
            FETCH c_cursor INTO division_id, overs, cards;
            LOOP
              if "+s+" then 
                if cards is not null then
                  l_card := l_card + cards;
                end if;
                if overs is not null then
                  l_over := l_over + overs;
                end if;
              end if;
              FETCH c_cursor INTO division_id, overs, cards;
              EXIT WHEN c_cursor%NOTFOUND;
            END LOOP;
            :l_res := 0;
            if l_card > 0 then
              :l_res := l_over*100/l_card;
            end if;
          end; "
# RAILS_DEFAULT_LOGGER.info query +"++++++++++++++++++++++++++++"          
        return get_fact_from_odb odb_connect, query
      end
      if factor.fact_descriptor == 'get_fact_enroll_salary'  
        s = ' true '
        if level_id > 1
          s = "division_id in ("+odb_division_ids.join(',')+")"
        end
        program_names = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 6).last.value
        query = " 
          declare
            c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
            division_id pls_integer; 
            count pls_integer;
            m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
            l_res number(38,2);
            amount number(38,2);
          begin "+program_names_to_array(program_names)+
            FACT_OWNER+".vbr_kpi.get_sum_enroll_salary(TO_DATE('"+ 
            period.start_date.to_s+"','yyyy-mm-dd'), TO_DATE('"+ 
            period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, c_cursor); 
            l_res := 0;
            FETCH c_cursor INTO division_id, amount, count;
            LOOP
              if "+s+" then 
                if amount is not null then
                  l_res := l_res + amount;
                end if;        
              end if;
              FETCH c_cursor INTO division_id, amount, count;
              EXIT WHEN c_cursor%NOTFOUND;
            END LOOP;
            :l_res := l_res; 
          end; "
        return get_fact_from_odb odb_connect, query
      end
      if factor.fact_descriptor == 'get_fact_problem_pers'  
        s = ' true '
        if level_id > 1
          s = "division_id in ("+odb_division_ids.join(',')+")"
        end
        program_names = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 6).last.value
        query = "
        declare
          c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
          division_id pls_integer; 
          p_amount_all number(38,2);
          p_amount_expire number(38,2);
          amount number(38,2);
          expire number(38,2);
          l_res number(38,2);
          m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
        begin "+program_names_to_array(program_names)+
          FACT_OWNER+".vbr_kpi.get_rest_by_ct_type(TO_DATE('"+ 
          period.end_date.to_s+"','yyyy-mm-dd'), 
          'CREDIT_DOCUMENT', 'F', m_macro_table, c_cursor);
          amount := 0;
          expire := 0;
          FETCH c_cursor INTO division_id, p_amount_all, p_amount_expire;
          LOOP
            if "+s+" then 
              if p_amount_all is not null then
                amount := amount + p_amount_all;
              end if;
              if p_amount_expire is not null then
                amount := amount + p_amount_expire;
                expire := expire + p_amount_expire;
              end if;      
            end if;
            FETCH c_cursor INTO division_id, p_amount_all, p_amount_expire;
            EXIT WHEN c_cursor%NOTFOUND;
          END LOOP;
          :l_res := 0;
          if (amount+expire) != 0 then
           :l_res := expire*100/(amount+expire);
          end if;
        end;"
        return get_fact_from_odb odb_connect, query
      end
    end
    return 0
  end
    
  def get_fact_from_odb odb_connect, query
    plsql = odb_connect.parse(query)
    plsql.bind_param(':l_res', nil, Float)
    plsql.exec
    fact = plsql[':l_res'] ? plsql[':l_res'] : 0
    plsql.close
    return fact
  end
#      fact = 0
#      accounts = 0
#      client_bank = 0
#      gsm_banking = 0
#      active_accounts = 0
#      query = ''
#      odb_division_ids.each {|division_id|
#        case factor.fact_descriptor
#          when 'get_fact_problem_pers'
#            program_names = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 6).last.value
#            query = " 
#              declare
#                m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
#                l_res number(38,5);
#                p_amount_all number(38,2);
#                p_amount_expire number(38,2);
#              begin "+program_names_to_array(program_names)+
#                FACT_OWNER+".vbr_kpi.get_pers_pr_by_ct_type(TO_DATE('"+ 
#                period.end_date.to_s+"','yyyy-mm-dd'),"+
#                division_id.to_s+",m_macro_table, :l_res, p_amount_all, p_amount_expire);
#              end; "
#          when 'get_fact_from_rest'
#            program_names = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 6).last.value
#            query = " 
#              declare
#                m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
#                l_res number(38,2);
#              begin "+program_names_to_array(program_names)+
#                FACT_OWNER+".vbr_kpi.get_rest_by_ct_type(TO_DATE('"+ 
#                period.end_date.to_s+"','yyyy-mm-dd'),"+
#                division_id.to_s+",'CREDIT_DOCUMENT', m_macro_table, :l_res);
#              end; "     
# RAILS_DEFAULT_LOGGER.info query+"++++++++++++++++++++++++++++"                
#          when 'get_fact_transfer'
#            query = " 
#              declare
#                l_res number(38,2);
#              begin "+
#                FACT_OWNER+".vbr_kpi.get_count_transfer(TO_DATE('"+ 
#                period.start_date.beginning_of_year.to_s+
#                "','yyyy-mm-dd'), TO_DATE('"+ period.end_date.to_s+"','yyyy-mm-dd'),"+ 
#                division_id.to_s+", :l_res);  
#              end; "
              
#          when 'get_fact_depobox'    
#            program_names = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 6).last.value
#            query = " 
#              declare
#                m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
#                l_res number(38,2);
#              begin "+program_names_to_array(program_names)+
#                FACT_OWNER+".vbr_kpi.get_count_depobox(TO_DATE('"+ 
#                period.end_date.to_s+"','yyyy-mm-dd'),"+ 
#                division_id.to_s+", m_macro_table, :l_res); 
#              end; "     
#          when 'get_fact_cash' #доходы по валютообменным операциям 
# '0%' - казначейские
# '1%' - ИБ
# '%'  - все             
#            query = " 
#              declare
#                l_res number(38,2);
#              begin "+
#                FACT_OWNER+".vbr_kpi.get_sum_nt_cash(TO_DATE('"+
#                period.start_date.beginning_of_year.to_s+"','yyyy-mm-dd'),
#                TO_DATE('"+ period.end_date.to_s+"','yyyy-mm-dd'),"+
#                division_id.to_s+", '1%', :l_res);
#              end; "
              
            
#          when 'get_fact_municipal'
#            query = " 
#              declare
#                l_res number(38,2);
#              begin "+
#                FACT_OWNER+".vbr_kpi.get_count_municipal(TO_DATE('"+
#                period.start_date.beginning_of_year.to_s+"','yyyy-mm-dd'), 
#                TO_DATE('"+ period.end_date.to_s+"','yyyy-mm-dd'),"+ 
#                division_id.to_s+", :l_res);  
#              end; "
            
#          when 'get_fact_deposit_volume'
#            program_names = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 6).last.value
#            query = " 
#              declare
#                m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
#                l_res number(38,2);
#              begin "+program_names_to_array(program_names)+
#                FACT_OWNER+".vbr_kpi.get_rest_by_ct_type(TO_DATE('"+ 
#                period.end_date.to_s+"','yyyy-mm-dd'),"+
#                division_id.to_s+", 'DEPOSIT_DOCUMENT', m_macro_table, l_res);
#                :l_res := l_res * (-1); 
#              end; "  
              # deposite have negative value. Need * (-1)
#          when 'get_fact_card_count'
#            program_names = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 6).last.value
#            query = " 
#              declare
#                m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
#                l_res number(38,2);
#              begin "+program_names_to_array(program_names)+
#                FACT_OWNER+".vbr_kpi.get_count_card(TO_DATE('"+ 
#                period.end_date.to_s+"','yyyy-mm-dd'),"+
#                division_id.to_s+", m_macro_table, :l_res);
#              end; "  
#          when 'get_fact_card_over'
#            program_names = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 6).last.value
#            query = " 
#              declare
#                m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
#                l_res number(38,2);
#              begin "+program_names_to_array(program_names)+
#                FACT_OWNER+".vbr_kpi.get_pers_card_over(TO_DATE('"+ 
#                period.end_date.to_s+"','yyyy-mm-dd'),"+
#                division_id.to_s+", m_macro_table, :l_res);
#              end; "
#              RAILS_DEFAULT_LOGGER.info query+"++++++++++++++++++++++++++++"              
#          when 'get_fact_card_ick' then # процент охвата зарплатных карт кредитными
#            query = " 
#              declare
#                l_res number(38,2);
#              begin "+
#                FACT_OWNER+".vbr_kpi.get_pers_card_ick(TO_DATE('"+ period.end_date.to_s+"','yyyy-mm-dd'),"+
#                  division_id.to_s+", :l_res);
#              end; "  
#          when 'get_count_term' then # Количество терминальных устройств на дату 
#            terminal_type = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 10).last.value
#            query = " 
#              declare
#                m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
#                l_res number(38,2);
#              begin "+program_names_to_array(terminal_type)+
#                FACT_OWNER+".vbr_kpi.get_count_term(TO_DATE('"+
#                  period.end_date.to_s+"','yyyy-mm-dd'),"+
#                  division_id.to_s+", m_macro_table, :l_res);
#              end; "     
# RAILS_DEFAULT_LOGGER.info query+"++++++++++++++++++++++++++++"               
#          when 'get_fact_open_accounts'
#            program_names = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 6).last.value
#            query = " 
#              declare
#                m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
#                l_res number(38,2);
#                res_client_bank number(38,2); 
#                res_gsm number(38,2);
#                res_active number(38,2);
#              begin "+program_names_to_array(program_names)+
#                FACT_OWNER+".vbr_kpi.get_count_tariff(TO_DATE('"+ 
#                period.end_date.to_s+"','yyyy-mm-dd'),"+
#                division_id.to_s+", m_macro_table, :l_res, res_client_bank, res_gsm, res_active);
#              end; "
#          when 'get_fact_percent_kb_servises_using'
#            query = "
#              declare
#                m_macro_table SR_BANK.t_str_table := SR_BANK.t_str_table();
#                l_accounts number(38,2);
#                l_client_bank number(38,2);
#                l_gsm_banking number(38,2);
#                l_res number(38,2);
#              begin 
#                m_macro_table.extend;
#                m_macro_table(1) := SR_BANK.T_STR_ROW('KSTG'); "+
#                FACT_OWNER+".vbr_kpi.get_count_tariff(TO_DATE('"+
#                period.end_date.to_s+"','yyyy-mm-dd'), "+
#                division_id.to_s+", m_macro_table, :l_accounts, :l_client_bank, :l_gsm_banking, l_res);
#              end; "
#          when 'get_fact_percent_accounts_active'
#            query = "
#              declare
#                m_macro_table SR_BANK.t_str_table := SR_BANK.t_str_table();
#                l_accounts number(38,2);
#                l_client_bank number(38,2);
#                l_gsm_banking number(38,2);
#                l_actives number(38,2);
#              begin 
#                m_macro_table.extend;
#                m_macro_table(1) := SR_BANK.T_STR_ROW('KSTG'); "+
#                FACT_OWNER+".vbr_kpi.get_count_tariff(TO_DATE('"+
#                period.end_date.to_s+"','yyyy-mm-dd'), "+
#                division_id.to_s+", m_macro_table, :l_accounts, l_client_bank, l_gsm_banking, :l_actives);
#              end; "
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
#          when 'get_fact_from_rest_average'
#            program_names = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 6).last.value
#            query = " 
#              declare
#                m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
#                l_res number(38,2);
#              begin "+program_names_to_array(program_names)+
#                FACT_OWNER+".vbr_kpi.get_rest_by_ct_type(TO_DATE('"+ 
#                period.end_date.to_s+"','yyyy-mm-dd'),"+
#                division_id.to_s+", 'DEPOSIT_DOCUMENT', m_macro_table, :l_res);
#              end; "
#          when 'get_fact_enroll_salary'
#            program_names = Param.where('factor_id=? and action_id=2 and param_description_id=?', factor.id, 6).last.value
#            query = " 
#              declare
#                m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
#                l_res number(38,2);
#                l_res2 number(38,2);
#              begin "+program_names_to_array(program_names)+
#                FACT_OWNER+".vbr_kpi.get_sum_enroll_salary(TO_DATE('"+ 
#                period.start_date.to_s+"','yyyy-mm-dd'), TO_DATE('"+ 
#                period.end_date.to_s+"','yyyy-mm-dd'),"+
#                division_id.to_s+", m_macro_table, :l_res, l_res2);
#              end; "
# RAILS_DEFAULT_LOGGER.info query+"++++++++++++++++++++++++++++"               
=begin
--Объем и количество по операциям выдачи кредитов
declare
  m_macro_table sr_bank.t_str_table := sr_bank.t_str_table();
  l_res1 number(38,2);
  l_res2 number(38,2);
begin
  m_macro_table.extend;
  m_macro_table(1) := sr_bank.T_STR_ROW('KK');
  sr_bank.vbr_kpi.get_sum_cred_out(TO_DATE('2011-01-01','yyyy-mm-dd'),
  TO_DATE('2011-09-30','yyyy-mm-dd'), 63, m_macro_table, l_res2, l_res2);
  sr_bank.p_exception.raise_common_except('_-'||l_res1||'_-'||l_res2||'=-_');
end;  
=end
#        end
#        if query > ''
#          plsql = odb_connect.parse(query)
#          case factor.fact_descriptor
#            when 'get_fact_percent_kb_servises_using'
#              plsql.bind_param(':l_accounts', nil, Fixnum) 
#              plsql.bind_param(':l_client_bank', nil, Fixnum) 
#              plsql.bind_param(':l_gsm_banking', nil, Fixnum) 
#              plsql.exec
#              accounts = accounts+(plsql[':l_accounts'] ? plsql[':l_accounts'] : 0)
#              client_bank = client_bank+(plsql[':l_client_bank'] ? plsql[':l_client_bank'] : 0)
#              gsm_banking = gsm_banking+(plsql[':l_gsm_banking'] ? plsql[':l_gsm_banking'] : 0)
#            when 'get_fact_percent_accounts_active'  
#              plsql.bind_param(':l_accounts', nil, Fixnum) 
#              plsql.bind_param(':l_actives', nil, Fixnum) 
#              plsql.exec
#              accounts = accounts+(plsql[':l_accounts'] ? plsql[':l_accounts'] : 0)
#              active_accounts = active_accounts+(plsql[':l_actives'] ? plsql[':l_actives'] : 0)
#            else  
#              plsql.bind_param(':l_res', nil, Float) 
#              plsql.exec
#              fact = fact+(plsql[':l_res'] ? plsql[':l_res'] : 0)
#          end
#          plsql.close
#        end
#      }
#      case factor.fact_descriptor
#        when 'get_fact_percent_kb_servises_using'
#          return accounts > 0 ? (client_bank+gsm_banking)*100.0/accounts : 0
#        when 'get_fact_percent_accounts_active'
#          return accounts > 0 ? active_accounts*100.0/accounts : 0
#        else  
#          return fact
#      end  
#    end
##
#    return 0
#  end
#              RAILS_DEFAULT_LOGGER.info sql+"++++++++++++++++++++++++++++"  

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
    res = ''
    y = period.start_date.year.to_s+"_"
    s_d = '1_1' # s_m.to_s+'_'+start_date.day.to_s
    e_d = period.end_date.month.to_s+'_'+period.end_date.day.to_s
    codes.each {|c|
      res = res + "(r"+c+".MONTH_"+y+e_d+" - r"+c+".MONTH_"+y+s_d+")+"
    }  
    return res[0,res.length-1]
  end  

  def get_fact_fin_res period, codes, article
#  get fact from FD not ODB    
    query = "select ("+get_fact_from_result(period, codes)+
      ") as fact from "+PLAN_OWNER+".directory d "+
      get_joins_for_result(codes)+
      " where d.namepp in ("+article+")"
    return PlanDictionary.find_by_sql(query).first.fact
  end

  def make_from codes
    res = ''
    codes.each {|c|
      res = res+PLAN_OWNER+".REZULT_"+c+" r"+c+","
    }
    return res[0, res.length-1]
  end
  
  def make_where codes, article
    res = ''
    codes.each {|c|
      res = res+article+"= r"+c+".id_directory and "
    }
    return res[0, res.length-4]
  end
  
  def get_fact_fin_res_2 period, codes, article
    article_id = PlanDictionary.find_by_sql("select id from "+PLAN_OWNER+".directory where namepp in ("+article+")").first.id
    query = "select ("+get_fact_from_result(period, codes)+
      ") as fact from "+make_from(codes)+
      " where "+make_where(codes, article_id.to_s)
    return PlanDictionary.find_by_sql(query).first.fact
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
    if worker_id
      @performances = Performance.where("period_id=? and division_id=? and direction_id=? and employee_id=? and calc_date in (
        select max(calc_date) from performances where period_id=? and division_id=? and direction_id=? and employee_id=?
        group by factor_id order by factor_id)",
        period_id, division_id, direction_id, worker_id, period_id, division_id, direction_id, worker_id).order(:block_id, :factor_id)
    else
    @performances = Performance.where("period_id=? and division_id=? and direction_id=? and calc_date in (
      select max(calc_date) from performances where period_id=? and division_id=? and direction_id=? 
      group by factor_id order by factor_id)",
      period_id, division_id, direction_id, period_id, division_id, direction_id).order(:block_id, :factor_id)
    end  
  end
   
  def get_odb_division_id fd_division_id
    return Division.find_by_code(BranchOfBank.find(fd_division_id).code).id
  end
  
  def find_direction
    @direction = Direction.find params[:direction_id]    
  end
  
  def find_period
    @period = Period.find params[:period_id]    
  end
# RAILS_DEFAULT_LOGGER.info query +"++++++++++++++++++++++++++++"
  def calc_kpi_for_all_divisions period, direction, odb_connect
    code_by_id = {}
    bb = BranchOfBank.where('open_date is not null').order(:code)
    bb.each {|b| code_by_id[b.id] = b.code}
    plans = {}
    facts = {}
    facts_by_worker = {}
    plans_by_worker = {}
    for b in direction.blocks do  
      for f in b.factors do
        facts_by_worker.clear
        plans_by_worker.clear
        if f.factor_weights.last.weight > 0.00001
          plans.clear
          facts.clear
          if (not f.plan_descriptor.nil?) and f.plan_descriptor > ''
            case f.plan_descriptor
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
                cards_account_rest_average = PlanDictionary.find_by_sql(query)
                plans.clear
                facts.clear
                cards_account_rest_average.each {|rest|
                  plans[rest.code] = rest.plan
                  facts[rest.code.to_i] = rest.fact
                }
              when 'get_plan_from_bp_new_by_begin_year'
                article = Param.where('factor_id=? and action_id=1 and param_description_id=4', f.id).last.value
                query ="    
                  select d.code, "+make_fields_list(period.start_date.beginning_of_year, period.end_date)+" plan from
                     "+FIN_OWNER+".factor f,
                     "+FIN_OWNER+".bud_value v,
                     "+FIN_OWNER+".bud_prefix p,
                     "+FIN_OWNER+".division d
                   where f.id = v.factor_id(+)
                     and v.bud_prefix_id = p.id
                     and p.id = 4 
                     and f.code in ("+article+")
                     and v.division_id = d.id
                     and d.code in ("+code_by_id.values.join(',')+") group by d.code"
                plan_by_code = PlanDictionary.find_by_sql(query)
                plans.clear
                plan_by_code.each {|p|
                  plans[p.code] = p.plan
                }
              when 'get_plan_over_average' # plan & fact
                business = Param.where('factor_id=? and action_id=1 and param_description_id=11', f.id).last.value
                query = "  
                  select div.code, abs(sum(dfp.base_amount)) as fact, sum(dfp.plan) plan
                    from "+FIN_OWNER+".credit_deposit_value dfp,
                      (SELECT ID FROM "+FIN_OWNER+".credit_deposit_factor t
                        CONNECT BY PRIOR t.ID = t.PARENT_ID START WITH id =25) tree,
                      (SELECT d.id, d.code FROM "+FIN_OWNER+".division d
                            where d.fact=1 and d.code in ("+code_by_id.values.join(',')+")) div
                    where 
                      dfp.sr_busines_id like (select id from "+FIN_OWNER+".sr_busines where code = '"+business+"')
                      and dfp.division_id = div.id
                      and dfp.credit_deposit_factor_id =tree.id
                      and dfp.periods_id="+period.id.to_s+" group by div.code"
                overs = PlanDictionary.find_by_sql(query)
                plans.clear
                facts.clear
                overs.each {|o|
                  plans[o.code] = o.plan
                  facts[o.code.to_i] = o.fact
                }
              when 'get_plan_const'  
                plan = Param.where('factor_id=? and action_id=1 and param_description_id=8', f.id).last.value.to_i
                plans.clear
                code_by_id.each_value {|c|
                  plans[c] = plan
                }
              when 'get_plan_from_bp_new'
                article = Param.where('factor_id=? and action_id=1 and param_description_id=4', f.id).last.value
                plans.clear
                code_by_id.each_value {|c|
                  query = "
                    select sum(v.mes"+period.end_date.month.to_s+") plan from
                      "+FIN_OWNER+".factor f, 
                      "+FIN_OWNER+".bud_value v,
                      "+FIN_OWNER+".bud_prefix p,
                      "+FIN_OWNER+".division d
                      where f.id = v.factor_id(+)
                      and v.bud_prefix_id = p.id
                      and p.id = 4 /*с учетом всех корректировок*/
                      and f.code in ("+article+")
                      and v.division_id = d.id
                      and d.code in ("+c+")"
                  p = PlanDictionary.find_by_sql(query).last
                  plans[c] = p.plan
                }
              when 'get_plan_fin_res' # plan & fact
                article = Param.where('factor_id=? and action_id=1 and param_description_id=5', f.id).last.value
                article_id = PlanDictionary.find_by_sql("select id from "+PLAN_OWNER+".directory where namepp in ("+article+")").first.id
                plans.clear
                facts.clear
                code_by_id.each_value {|c|
                  query = ''
                  res = ''
                  s_m = 1 #period.start_date.month
                  e_m = period.end_date.month
                  s_d = 1 #period.start_date.day
                  e_d = period.end_date.day
                  y = period.end_date.year
                  al = 'r'+c
                  for i in s_m..e_m
                    res = res+al+'.plan_'+i.to_s+'+'
                  end
                  res = res[0, res.length-1]
                  query = "select ("+res+") as plan, (r"+c+".MONTH_"+y.to_s+"_"+e_m.to_s+"_"+e_d.to_s+
                    " - r"+c+".MONTH_"+y.to_s+"_"+s_m.to_s+"_"+s_d.to_s+") as fact from "+PLAN_OWNER+
                    ".REZULT_"+c+" r"+c+" where "+article_id.to_s+"= r"+c+".id_directory"
            
                  fin_res = PlanDictionary.find_by_sql(query).last
                  plans[c] = fin_res.plan
                  facts[c.to_i] = fin_res.fact
                }
            end
          end
          if (not f.fact_descriptor.nil?) and f.fact_descriptor > ''
            if f.fact_descriptor == 'get_fact_problem_percent_by_worker'  
              program_names = Param.where('factor_id=? and action_id=2 and param_description_id=6', f.id).last.value
              query = "
              declare
                c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
              begin "+program_names_to_array(program_names)+
                FACT_OWNER+".vbr_kpi.get_rest_by_ct_type(TO_DATE('"+ 
                period.end_date.to_s+"','yyyy-mm-dd'), 
                'CREDIT_DOCUMENT', 'T', m_macro_table, :c_cursor);
              end;"
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close

              # r[0] => division_id
              # r[1] => user_id
              # r[2] => ammount_rest
              # r[3] => ammount_exp
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
              program_names = Param.where('factor_id=? and action_id=2 and param_description_id=6', f.id).last.value
              query = "
              declare
                c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
              begin "+program_names_to_array(program_names)+
                FACT_OWNER+".vbr_kpi.get_rest_by_ct_type(TO_DATE('"+ 
                period.end_date.to_s+"','yyyy-mm-dd'), 
                'CREDIT_DOCUMENT', 'T', m_macro_table, :c_cursor);
              end;"
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close

              # r[0] => division_id
              # r[1] => user_id
              # r[2] => ammount_rest
              # r[3] => ammount_exp
              facts_by_worker.clear
              while r = cursor.fetch()
                e = Employee.find_by_sr_user_id(r[1])
                if not e.nil?
                  pers_number = e.tabn.to_i
                  facts_by_worker[pers_number] = r[3]+r[2]
                end  
              end
              query = "
              declare
                c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
              begin "+program_names_to_array(program_names)+
                FACT_OWNER+".vbr_kpi.get_rest_by_ct_type(TO_DATE('"+ 
                period.start_date.yesterday.to_s+"','yyyy-mm-dd'), 
                'CREDIT_DOCUMENT', 'T', m_macro_table, :c_cursor);
              end;"
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close
              while r = cursor.fetch()
                e = Employee.find_by_sr_user_id(r[1])
                if not e.nil?
                  pers_number = e.tabn.to_i
                  facts_by_worker[pers_number] = facts_by_worker[pers_number]-(r[3]+r[2])
                end  
              end
            end
            if f.fact_descriptor == 'get_fact_problem_pers'  
              program_names = Param.where('factor_id=? and action_id=2 and param_description_id=6', f.id).last.value
              query = "
              declare
                c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
              begin "+program_names_to_array(program_names)+
                FACT_OWNER+".vbr_kpi.get_rest_by_ct_type(TO_DATE('"+ 
                period.end_date.to_s+"','yyyy-mm-dd'), 
                'CREDIT_DOCUMENT', 'F', m_macro_table, :c_cursor);
              end;"
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close

              # r[0] => division_id
              # r[1] => ammount_rest
              # r[2] => ammount_exp
              facts.clear
              while r = cursor.fetch()
                code = Division.find(r[0]).code.to_i
                if (r[1]+r[2])!=0
                  facts[code] = r[2]*100/(r[1]+r[2])
                else  
                  facts[code] = 0
                end  
              end
            end
            if (f.fact_descriptor == 'get_fact_from_rest_by_program') or (f.fact_descriptor == 'get_fact_from_rest')
              program_names = Param.where('factor_id=? and action_id=2 and param_description_id=6', f.id).last.value
              query = "
              declare
                c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
              begin "+program_names_to_array(program_names)+
                FACT_OWNER+".vbr_kpi.get_rest_by_ct_type(TO_DATE('"+ 
                period.end_date.to_s+"','yyyy-mm-dd'), 
                'CREDIT_DOCUMENT', 'F', m_macro_table, :c_cursor);
              end;"
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close

              # r[0] => division_id
              # r[1] => ammount_rest
              # r[2] => ammount_exp
              facts.clear
              while r = cursor.fetch()
                code = Division.find(r[0]).code.to_i
                facts[code] = r[1]+r[2]
              end
            end
            if f.fact_descriptor == 'get_fact_from_values'
              facts.clear
              code_by_id.each {|division_id, c|
                facts[c.to_i] = get_fact_from_values period.id, division_id, f.id
              }  
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
                    and d.code in ("+code_by_id.values.join(',')+") group by d.code"    
              credits = PlanDictionary.find_by_sql(query)
              facts.clear
              credits.each {|credit|
                facts[credit.code.to_i] = credit.fact
              }
            end
            if f.fact_descriptor == 'get_fact_transfer'
              query = " 
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                begin "+
                  FACT_OWNER+".vbr_kpi.get_count_transfer(TO_DATE('"+ 
                  period.start_date.beginning_of_year.to_s+
                  "','yyyy-mm-dd'), TO_DATE('"+ 
                  period.end_date.to_s+"','yyyy-mm-dd'), :c_cursor); 
                end; "
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close

              # r[0] => division_id
              # r[1] => amount
              facts.clear
              while r = cursor.fetch()
                code = Division.find(r[0]).code.to_i
                facts[code] = r[1]
              end
            end
            if f.fact_descriptor == 'get_fact_depobox' 
              program_names = Param.where('factor_id=? and action_id=2 and param_description_id=6', f.id).last.value
              query = " 
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                begin "+program_names_to_array(program_names)+
                  FACT_OWNER+".vbr_kpi.get_count_depobox(TO_DATE('"+ 
                  period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, :c_cursor); 
                end; "     
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close

              # r[0] => division_id
              # r[1] => amount
              facts.clear
              while r = cursor.fetch()
                code = Division.find(r[0]).code.to_i
                facts[code] = r[1]
              end
            end
            if f.fact_descriptor == 'get_fact_fin_res'
              article = Param.where('factor_id=? and action_id=2 and param_description_id=5', f.id).last.value
              article_id = PlanDictionary.find_by_sql("select id from "+PLAN_OWNER+".directory where namepp in ("+article+")").first.id
              facts.clear
              code_by_id.each_value {|c|
                query = ''
                res = ''
                e_m = period.end_date.month
                e_d = period.end_date.day
                y = period.end_date.year
                query = "select (r"+c+".MONTH_"+y.to_s+"_"+e_m.to_s+"_"+e_d.to_s+
                  " - r"+c+".MONTH_"+y.to_s+"_1_1) as fact from "+PLAN_OWNER+
                  ".REZULT_"+c+" r"+c+" where "+article_id.to_s+"= r"+c+".id_directory"
          
                fin_res = PlanDictionary.find_by_sql(query).last
                facts[c.to_i] = fin_res.fact
              }
            end
            if f.fact_descriptor == 'get_fact_municipal_by_contract'
              query = "
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                begin
                  "+FACT_OWNER+".vbr_kpi.get_count_municipal(TO_DATE('"+
                  period.start_date.beginning_of_year.to_s+"','yyyy-mm-dd'),
                  TO_DATE('"+ period.end_date.to_s+"','yyyy-mm-dd'), :c_cursor);
                end;"            
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close

              # r[0] => division_id
              # r[1] => contract_id 
              # r[2] => count_payment
              # r[3] => count_payment2
              facts.clear
              curr_code = 0
              municipal_count = 0
              while r = cursor.fetch()
                code = Division.find(r[0]).code.to_i
                if code != curr_code
                  if curr_code != 0
                    facts[curr_code] = municipal_count
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
      #         case when mp.contract_id in
      #         (17608,  -- ПКТС
      #          12205,  -- ЕРЦ
      #          24991,  -- флэш-киоск
      #          10990,  -- пополнения моб. операторов
      #          23961)  -- СДА             
#                RAILS_DEFAULT_LOGGER.info Time.now.to_s+ "++++++++++++time2++++++++++++++++"
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
              deposits = PlanDictionary.find_by_sql(query)
              facts.clear
              deposits.each {|fact|
                facts[fact.code.to_i] = fact.deposit
              }
#              if fd_division_id.to_i == 1
#               if businnes_code == 'I'
#                 s = " where dfp.division_id != 1 and "
#               else
#                 s = " where "
#               end
#              else  
#                s = ", (SELECT d.id, d.name, d.code FROM "+FIN_OWNER+".division d
#                    where d.fact=1 and d.code in ("+get_codes_divisions_as_str(fd_division_id)+")) div
#                  where dfp.division_id = div.id and "
#              end
            end
            if f.fact_descriptor == 'get_fact_card_count'
              program_names = Param.where('factor_id=? and action_id=2 and param_description_id=6', f.id).last.value
              query = " 
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                begin "+program_names_to_array(program_names)+
                  FACT_OWNER+".vbr_kpi.get_count_card(TO_DATE('"+ 
                  period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, :c_cursor); 
                end; "  
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close

              # r[0] => division_id
              # r[1] => amount
              facts.clear
              while r = cursor.fetch()
                code = Division.find(r[0]).code.to_i
                facts[code] = r[1]
              end
            end
            if f.fact_descriptor == 'get_fact_card_over'  
              program_names = Param.where('factor_id=? and action_id=2 and param_description_id=6', f.id).last.value
              query = " 
                declare
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                begin "+program_names_to_array(program_names)+
                  FACT_OWNER+".vbr_kpi.get_pers_card_over(TO_DATE('"+ 
                  period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, :c_cursor);
                end; "
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close

              # r[0] => division_id
              # r[1] => overs
              # r[2] => cards
              facts.clear
              while r = cursor.fetch()
                code = Division.find(r[0]).code.to_i
                if (not r[2].nil?) and (r[2]!=0)
                  if r[1].nil?
                    facts[code] = 0
                  else
                    facts[code] = r[1]*100/r[2]
                  end
                else  
                  facts[code] = 0
                end
              end
            end
            if f.fact_descriptor == 'get_fact_card_ick' # процент охвата зарплатных карт кредитными 
              query = " 
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                begin "+
                  FACT_OWNER+".vbr_kpi.get_pers_card_ick(TO_DATE('"+period.end_date.to_s+"','yyyy-mm-dd'),:c_cursor);
                end; "  
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close

              # r[0] => division_id
              # r[1] => overs
              # r[2] => cards
              facts.clear
              while r = cursor.fetch()
                code = Division.find(r[0]).code.to_i
                if (not r[2].nil?) and (r[2]!=0)
                  if r[1].nil?
                    facts[code] = 0
                  else
                    facts[code] = r[1]*100/r[2]
                  end
                else  
                  facts[code] = 0
                end
              end
            end
            if f.fact_descriptor == 'get_count_term' # Количество терминальных устройств на дату
              terminal_type = Param.where('factor_id=? and action_id=2 and param_description_id=10', f.id).last.value
              query = " 
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                begin "+program_names_to_array(terminal_type)+
                  FACT_OWNER+".vbr_kpi.get_count_term(TO_DATE('"+
                    period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, :c_cursor); 
                end; "     
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close

              # r[0] => division_id
              # r[1] => amount
              facts.clear
              while r = cursor.fetch()
                code = Division.find(r[0]).code.to_i
                facts[code] = r[1]
              end
            end
            if f.fact_descriptor == 'get_fact_open_accounts' 
              program_names = Param.where('factor_id=? and action_id=2 and param_description_id=6', f.id).last.value
              query = " 
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                begin "+program_names_to_array(program_names)+
                  FACT_OWNER+".vbr_kpi.get_count_tariff(TO_DATE('"+ 
                  period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, :c_cursor);
                end; "   
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close

              # r[0] => division_id
              # r[1] => amount
              # r[2] => amount_cb
              # r[3] => amount_gsm
              # r[4] => amount_active
              facts.clear
              while r = cursor.fetch()
                code = Division.find(r[0]).code.to_i
                facts[code] = r[1]
              end
            end
            if f.fact_descriptor == 'get_fact_enroll_salary'  
              program_names = Param.where('factor_id=? and action_id=2 and param_description_id=6', f.id).last.value
              query = " 
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                begin "+program_names_to_array(program_names)+
                  FACT_OWNER+".vbr_kpi.get_sum_enroll_salary(TO_DATE('"+ 
                  period.start_date.to_s+"','yyyy-mm-dd'), TO_DATE('"+ 
                  period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, :c_cursor);
                end; "   
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close

              # r[0] => division_id
              # r[1] => amount
              # r[2] => count
              facts.clear
              while r = cursor.fetch()
                code = Division.find(r[0]).code.to_i
                facts[code] = r[1]
              end
            end
            if f.fact_descriptor == 'get_fact_percent_accounts_active' 
              query = "
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                begin 
                  m_macro_table.extend;
                  m_macro_table(1) := "+FACT_OWNER+".T_STR_ROW('KSTG'); "+
                  FACT_OWNER+".vbr_kpi.get_count_tariff(TO_DATE('"+
                  period.end_date.to_s+"','yyyy-mm-dd'), m_macro_table, :c_cursor);
                end;"
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close

              # r[0] => division_id
              # r[1] => amount
              # r[2] => amount_cb
              # r[3] => amount_gsm
              # r[4] => amount_active
              facts.clear
              while r = cursor.fetch()
                code = Division.find(r[0]).code.to_i
                if (not r[1].nil?) and (r[1]!=0)
                  if r[4].nil?
                    facts[code] = 0
                  else
                    facts[code] = r[4]*100/r[1]
                  end
                else
                  facts[code] = 0
                end
              end
            end
            if f.fact_descriptor == 'get_fact_credit_contract_number' 
              program_names = Param.where('factor_id=? and action_id=2 and param_description_id=6', f.id).last.value
              query = "
                declare
                  c_cursor "+FACT_OWNER+".vbr_kpi.common_cursor;
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                begin "+program_names_to_array(program_names)+
                  FACT_OWNER+".vbr_kpi.get_count_credit(TO_DATE('"+
                  period.end_date.to_s+"','yyyy-mm-dd'), 'T', m_macro_table, :c_cursor);
                end;"
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close

              # r[0] => division_id
              # r[1] => user_id
              # r[2] => contract_amount
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
              plsql = odb_connect.parse(query)
              plsql.bind_param(':c_cursor', OCI8::Cursor) 
              plsql.exec
              cursor = plsql[':c_cursor']
              plsql.close
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
          end
          if direction.level_id == 4
            prepare_and_save_kpi_by_workers code_by_id, plans_by_worker, facts_by_worker, plans, facts, b.direction_id, f.block_id, f.id, period.id, 
              b.block_weights.last.weight, f.factor_weights.last.weight
          else
            prepare_and_save_kpi code_by_id, plans, facts, b.direction_id, f.block_id, f.id, period.id, 
              b.block_weights.last.weight, f.factor_weights.last.weight
          end  
        end
      end 
    end
  end

  def prepare_and_save_kpi_by_workers code_by_id, plans_by_worker, facts_by_worker, plans, facts, direction_id, block_id, factor_id, period_id, bw, fw
    @workers.each {|w|
      fact = 0
      code = w.code_division[0, 3]
      fullname = w.lastname.to_utf+' '+w.firstname.to_utf+' '+w.soname.to_utf
      if plans_by_worker[w.id.to_i] and not plans_by_worker[w.id.to_i].nil?
        plan = plans_by_worker[w.id.to_i]
      else
        plan = (plans[code] and not plans[code].nil?) ? plans[code] : 0
      end

      if facts_by_worker[w.tabn.to_i] and not facts_by_worker[w.tabn.to_i].nil?
        fact = facts_by_worker[w.tabn.to_i]
      else
        fact = (facts[code.to_i] and not facts[code.to_i].nil?) ? facts[code.to_i] : 0
      end
      rate = bw * fw
      if Factor.find(factor_id).factor_description.short_name == "% проблемности" 
        percent = get_problem_percent(factor_id, fact)
      else
        percent = ((plan != 0) ? 100*fact.to_f/plan.to_f : 0)
      end
      percent = 200 if percent > 200
  
      kpi = rate*percent
      save_kpi period_id, code_by_id.key(code), direction_id, block_id, factor_id, 
        w.id, fullname, 
        rate, plan, fact, percent, kpi 
    }
  end

  def prepare_and_save_kpi code_by_id, plans, facts, direction_id, block_id, factor_id, period_id, bw, fw
    plans.each {|code, value|
      plan = value ? value : 0
      fact = (facts[code.to_i] and not facts[code.to_i].nil?) ? facts[code.to_i] : 0
      rate = bw * fw

      if Factor.find(factor_id).factor_description.short_name == "% проблемности" 
        percent = get_problem_percent(factor_id, fact)
      else
        percent = ((plan != 0) ? 100*fact.to_f/plan.to_f : 0)
      end
      percent = 200 if percent > 200
  
      kpi = rate*percent
  
      save_kpi period_id, code_by_id.key(code), direction_id, block_id, factor_id, 
        0, # worker_id, 
        '', # fullname, 
        rate, plan, fact, percent, kpi 
    }
  end
#                RAILS_DEFAULT_LOGGER.info plans.values
#                RAILS_DEFAULT_LOGGER.info "++++++++++++++++++++++++++++"
#                p plan_fact.to_s+"++++++++++++++++++++++++++++"
  
end

