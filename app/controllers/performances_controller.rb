# coding: utf-8
class PerformancesController < ApplicationController
  PLAN_OWNER = 'RPK880508'
  FACT_OWNER = 'SR_BANK'
  def index
    @performances = Performance.order(:period_id, :direction_id, :division_id, :block_id, :factor_id)
  end

  def show_values
    @values = Performance.where("division_id=? and direction_id=? and factor_id=?",
      params[:division_id], params[:direction_id], params[:factor_id]).order(:period_id)
  end
    
  def get_report_params
  end

  def get_calc_params
  end

  def calc_kpi
    fd_division_id = (params[:report_params][:division_id])=="0" ? "1" : params[:report_params][:division_id]
    
    direction = Direction.find params[:report_params][:direction_id]
    odb_connection = OCI8.new("kpi", "R4EW9OLK", "srbank")
    for b in direction.blocks do  
      for f in b.factors do
        if f.articles.nil? or f.articles.size==0
          plan = 0
          fact = 0
        else
          plan = get_plan params[:report_params][:period_id], 
                          params[:report_params][:division_id], f.id
          fact = get_fact odb_connection, get_odb_division_id(fd_division_id), f.id
        end
        bw = b.block_weights.last
        fw = f.factor_weights.last
        rate = bw.weight * fw.weight
        percent = (plan != 0 ? 100*fact.to_f/plan.to_f : 0)
        kpi = rate*percent
        save_kpi params[:report_params][:period_id],
          params[:report_params][:division_id], 
          params[:report_params][:direction_id],
          b.id, f.id, rate, plan, fact, percent, kpi
      end
    end
    odb_connection.logoff
#    redirect_to :action => 'get_calc_params'
    redirect_to :action => :show_report, :report_params => {:period_id =>    params[:report_params][:period_id], 
                                                            :division_id =>  params[:report_params][:division_id], 
                                                            :direction_id => params[:report_params][:direction_id]}
  end
    
  def show_report
    get_kpi params[:report_params][:period_id], params[:report_params][:division_id], params[:report_params][:direction_id]
    if @performances.size == 0
      flash_error :kpi_not_ready
      redirect_to :action => 'get_report_params'
    end
  end
  
  def report_print
    get_kpi params[:period_id], params[:division_id], params[:direction_id]
    output = Report1.new(:page_size => "A4", :page_layout => :landscape, :margin => 20).to_pdf @performances 

    respond_to do |format|
      format.pdf do
        send_data output, :filename => "report1.pdf", :type => "application/pdf", :format => 'pdf'
      end
    end
  end
  
  private
  
  def get_plan period_id, division_id, factor_id #direction_id
    r =  division_id > '9' ? division_id : ('0'+division_id)
    factor = Factor.find factor_id
# this is wery hard code!
    factor.articles.collect {|article|
      if article.action_id == 1 # plan
        if article.name[0,2] == 'BP'    
          s = "select mes"+period_id+" plan from "+PLAN_OWNER+".bp_sprav s join "+PLAN_OWNER+".bp_0"+r+
            " bp on s.id = bp.id_sprav where s.namepp = '"+article.name+"'"
        else
          m = Period.find(period_id).start_date.strftime("%m").to_i
          ss = ''
          i = 0
          ss = ss+"plan_#{i+=1}+" while i<m
          ss = ss[0, ss.length-1]
          s = "select "+ss+" plan from "+PLAN_OWNER+".rezult_0"+r+" rs join "+PLAN_OWNER+
            ".directory d on d.id = rs.id_directory and d.namepp = '"+article.name+"'"
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

  def get_fact odb_connect, division_id, factor_id
    mt = ''
    Factor.find(factor_id).articles.collect { |a|
      if a.action_id == 2 # fact
        mt = mt + "
          m_macro_table.extend;
          m_macro_table(1) := "+FACT_OWNER+".T_STR_ROW('"+a.name+"');
        "
      end
    }
    sql = "
        declare
          m_macro_table "+FACT_OWNER+".t_str_table := "+FACT_OWNER+".t_str_table();
          l_res number(38,2);
        begin"+mt+"
          select "+FACT_OWNER+".vbr_kpi.get_rest_by_ct_tp("+FACT_OWNER+".ad,"+
            division_id.to_s+",'CREDIT_DOCUMENT',m_macro_table)
          into :l_res
          from dual;
        end;
        "     
    plsql = odb_connect.parse(sql)
    plsql.bind_param(':l_res', nil, Fixnum) 
    plsql.exec
    fact = plsql[':l_res']
    plsql.close
    return fact
  end
  
  def save_kpi period_id, division_id, direction_id, block_id, factor_id, rate, plan, fact, percent, kpi 
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
    @performances = Performance.where("period_id=? and division_id=? and direction_id=?",
      period_id, division_id, direction_id).order(:block_id, :factor_id)
  end
   
  def get_odb_division_id fd_division_id
    d = Division.where("code=?", fd_division_id.to_s).first
    return d.id
  end
end