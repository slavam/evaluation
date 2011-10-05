# coding: utf-8
class PerformancesController < ApplicationController
  PLAN_OWNER = 'RPK880508'
  FACT_OWNER = 'SR_BANK'
  def index
    @performances = Performance.order(:period_id, :direction_id, :division_id, :block_id, :factor_id)
  end

  def show_values
    @values = Performance.where('division_id=? and direction_id=? and factor_id=? and calc_date in(
      select max(calc_date) from performances where division_id=? and direction_id=? and factor_id=? 
      group by period_id order by period_id)',params[:division_id], params[:direction_id], params[:factor_id],
      params[:division_id], params[:direction_id], params[:factor_id]).order(:period_id)
    
#    @values = Performance.where("division_id=? and direction_id=? and factor_id=?",
#      params[:division_id], params[:direction_id], params[:factor_id]).order(:period_id)
  end
    
  def get_report_params
  end

  def get_calc_params
  end

  def calc_kpi
    fd_division_id = 
      (params[:report_params][:division_id])=="0" ? "1" : params[:report_params][:division_id]
    
    direction = Direction.find params[:report_params][:direction_id]
    odb_connection = OCI8.new("kpi", "R4EW9OLK", "srbank")
    for b in direction.blocks do  
      for f in b.factors do
        if f.factor_weights.last.weight > 0.00001
          if f.articles.nil? or f.articles.size==0
            plan = 0
            fact = 0
          else
            plan = get_plan params[:report_params][:period_id], 
                            params[:report_params][:division_id], f.id
            fact = get_fact odb_connection, get_odb_division_id(fd_division_id), f.id, params[:report_params][:period_id]
            fact = (fact ? fact : 0)
          end
          bw = b.block_weights.last
          fw = f.factor_weights.last
          rate = bw.weight * fw.weight
          percent = ((plan and (plan != 0))  ? 100*fact.to_f/plan.to_f : 0)
          kpi = rate*percent
          save_kpi params[:report_params][:period_id],
            params[:report_params][:division_id], 
            params[:report_params][:direction_id],
            b.id, f.id, rate, plan, fact, percent, kpi
        end
      end
    end
    odb_connection.logoff
    redirect_to :action => :show_report, 
      :report_params => {:period_id => params[:report_params][:period_id], 
      :division_id =>  params[:report_params][:division_id], 
      :direction_id => params[:report_params][:direction_id]}
  end
    
  def show_report
    get_kpi params[:report_params][:period_id], 
            params[:report_params][:division_id], 
            params[:report_params][:direction_id]
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

  def build_sql_for_results period_id, article_name, division_code
    m = Period.find(period_id).start_date.strftime("%m").to_i
    ss = ''
    i = 0
    ss = ss+"plan_#{i+=1}+" while i<m
    ss = ss[0, ss.length-1]
    return "select "+ss+" plan from "+PLAN_OWNER+".rezult_0"+division_code+" rs join "+PLAN_OWNER+
      ".directory d on d.id = rs.id_directory and d.namepp = '"+article_name+"'"
  end
  
  def get_plan period_id, division_id, factor_id #direction_id
    if division_id == '1'
      r = '00'      
    else
      r =  division_id > '9' ? division_id : ('0'+division_id)
    end  
    factor = Factor.find factor_id
# this is wery hard code!
    factor.articles.collect {|article|
      if article.action_id == 1 # plan
        if article.name[0,2] == 'BP'
          if article.name.include?('+')
            article.name.mb_chars[article.name.index('+'),1] = "', '"
          end  
          a = "'"+article.name+"'"
          if article.select_type_id == 1 # sum from start year
            period = Period.find period_id
            s = "select ("+get_months(period.start_date.beginning_of_year, period.start_date)+") plan from "+PLAN_OWNER+".bp_sprav s join "+
              PLAN_OWNER+".bp_0"+r+
              " bp on s.id = bp.id_sprav where s.namepp in ("+a+")"
          else
            s = "select sum(mes"+period_id+") plan from "+PLAN_OWNER+".bp_sprav s join "+
              PLAN_OWNER+".bp_0"+r+
              " bp on s.id = bp.id_sprav where s.namepp in ("+a+")"
          end
        else
          s = build_sql_for_results period_id, article.name, r
        end
        @plan = PlanDictionary.find_by_sql(s).last
        return @plan.plan
      end
    }
    return 0
=begin
total the bank    
select bp0.mes8+bp2.mes8+bp3.mes8+bp4.mes8+bp5.mes8+bp6.mes8+bp7.mes8
+bp9.mes8
+bp11.mes8
+bp12.mes8
+bp14.mes8
+bp15.mes8
+bp16.mes8
from RPK880508.bp_sprav s 
join RPK880508.bp_000 bp0 on s.id = bp0.id_sprav
join RPK880508.bp_002 bp2 on s.id = bp2.id_sprav
join RPK880508.bp_003 bp3 on s.id = bp3.id_sprav
join RPK880508.bp_004 bp4 on s.id = bp4.id_sprav
join RPK880508.bp_005 bp5 on s.id = bp5.id_sprav
join RPK880508.bp_006 bp6 on s.id = bp6.id_sprav
join RPK880508.bp_007 bp7 on s.id = bp7.id_sprav 
join RPK880508.bp_009 bp9 on s.id = bp9.id_sprav 
join RPK880508.bp_011 bp11 on s.id = bp11.id_sprav 
join RPK880508.bp_012 bp12 on s.id = bp12.id_sprav 
join RPK880508.bp_014 bp14 on s.id = bp14.id_sprav 
join RPK880508.bp_015 bp15 on s.id = bp15.id_sprav 
join RPK880508.bp_016 bp16 on s.id = bp16.id_sprav 
where s.namepp in ('BP.3.01.0.0.0.0')
    
=end    
# column_names      
#      p PlanDictionary.columns_hash.size.to_s+">>>>>>>>>>>>>>>>>>>>"
#      @fact = PlanDictionary.find_by_sql("select * from RPK880508.rezult_003 r
#        join rpk880508.directory d on d.id = r.id_directory and d.namepp = 'п00.00.05.01.00.00'").last
#      p @fact.attributes.sort.to_s+">>>>>>>>>>>>>>>>>>>>"
    
  end

  def get_months start_date, end_date
    s_m = start_date.month
    e_m = end_date.month
    m_a = []
    for i in (s_m..e_m)
      m_a << i 
    end
    return 'mes'+m_a.join('+mes')
  end
  
  def get_fact odb_connect, division_id, factor_id, period_id
    period = Period.find(period_id)
    Factor.find(factor_id).articles.collect { |a|
      if a.action_id == 2 and a.name[7,2] == '11' # get fact from FD
        if params[:report_params][:division_id] == '1'
          division_code = '00'
        else
          division_code = params[:report_params][:division_id] > '9' ? params[:report_params][:division_id] : ('0'+params[:report_params][:division_id])
        end
        return get_fin_res_fact('2011-01-01'.to_date, period.end_date, division_code, a.name)        
      end

      if a.action_id == 2 # fact
        mt = ''
        case a.name 
          when 'get_count_transfer' then
            sql = " declare
                  l_res number(38,2);
                begin
                  sr_bank.vbr_kpi.get_count_transfer(TO_DATE('2011-01-01','yyyy-mm-dd'), 
                  TO_DATE('"+ period.end_date.to_s+"','yyyy-mm-dd'),"+ division_id.to_s+", :l_res);  
                end; "     
          when 'get_count_municipal' then
            sql = " declare
                  l_res number(38,2);
                begin
                  sr_bank.vbr_kpi.get_count_municipal(TO_DATE('2011-01-01','yyyy-mm-dd'), 
                  TO_DATE('"+ period.end_date.to_s+"','yyyy-mm-dd'),"+ division_id.to_s+", :l_res);  
                end; "     
          else  
            mt = mt + "
              m_macro_table.extend;
              m_macro_table(1) := "+FACT_OWNER+".T_STR_ROW('"+a.name+"');"
            sql = " declare
                  m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
                  l_res number(38,2);
                begin"+mt+"
                  select "+FACT_OWNER+".vbr_kpi.get_rest_by_ct_tp("+FACT_OWNER+".ad,"+
                    division_id.to_s+",'CREDIT_DOCUMENT',m_macro_table)
                  into :l_res
                  from dual;
                end; "     
        end  
        plsql = odb_connect.parse(sql)
        plsql.bind_param(':l_res', nil, Fixnum) 
        plsql.exec
        fact = plsql[':l_res']
        plsql.close
        return fact
      end 
    }
    return 0
  end

  def get_fin_res_fact start_date, end_date, division_code, article
#  get fact from FD not ODB    
    y = start_date.year.to_s+"_"
    s_m = start_date.month
    e_m = end_date.month
    s_d = s_m.to_s+'_'+start_date.day.to_s
    e_d = e_m.to_s+'_'+end_date.day.to_s
    
    query = "select (t.MONTH_"+y+e_d+" - t.MONTH_"+y+s_d+") as fact
      from "+PLAN_OWNER+".REZULT_0"+division_code+" t, "+PLAN_OWNER+".DIRECTORY d
      where d.id = t.id_directory and d.namepp like '%"+article[1,article.size-1]+"'"
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

#select * from performances where period_id=1 and division_id=7 and direction_id=3 
#--order by factor_id
#and calc_date in(
#select max(calc_date) from performances where period_id=1 and division_id=7 and direction_id=3 
#group by factor_id
#order by factor_id
#)


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
#order by block_id, factor_id

  end
   
  def get_odb_division_id fd_division_id
    d = Division.where("code=?", fd_division_id.to_s).first
    return d.id
  end
end