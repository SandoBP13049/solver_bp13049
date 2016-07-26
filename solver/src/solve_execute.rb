#翻刻制約充足問題を解く
#実行クラス
require_relative './lattice.rb'
class SolveExecute
  def initialize(csp_file,n,dic_file,reading_file,matrix_file,da_file,da_rev_file,output_directory)
    csp_file = csp_file
    csp_hash = eval(File.read(csp_file))
    @csp = RS::CSP::ConstraintSatisfactionProblem.new(csp_hash)
    @csp.insert_dummy
    matrix = ConnectionMatrix.new(matrix_file)
    @lattice = Lattice.new
    if reading_file != nil
      reading = eval(File.read(reading_file))
      dic = Dictionary.new(dic_file)
      @lattice.build_from_reading(@csp,reading,dic,matrix)
    else
      dic_da = DoubleArray.new
      dic_da_rev = DoubleArray.new
      dic_da.load(da_file)
      dic_da_rev.load(da_rev_file)
      @lattice.build(@csp,dic_da,dic_da_rev,matrix)
    end
    @n=n
    @output_directory=output_directory

  end

  def execute()
    @lattice.calc_min_cost
    nbests = @lattice.nbest_search(@n)
    satisfaction_factory = RS::CSP::Evaluator::LPBSatisfactionFactory.new
    solutions = []
    0.upto(nbests.size-1) do |i|
      satisfaction = satisfaction_factory.create(@csp.constraints)
      satisfaction.set_readings(nbests[i][0][1..-2].map(&:to_assignment).each(&:init_pos))
      tmp_solutions=[]
      addition = true
      equality = false
      solutions.each do |s|
        if s[0].comparable?(satisfaction)
          if s[0] == satisfaction
            s.push(nbests[i])
            tmp_solutions.push(s)
            addition = false
          elsif s[0] > satisfaction
            tmp_solutions.push(s)
            addition = false
          end
        else
          tmp_solutions.push(s)
        end
      end
      if addition
        tmp_solutions.push([satisfaction,nbests[i]])
      end
      solutions = tmp_solutions
    end
solutions=solutions.inject([]){|ret,s| ret.concat(s[1..-1])} #制約充足度を取り除く
solutions.sort!{|a,b| a[1]<=>b[1]} #総コストでソート
#solutions[0..10].each{|s| p s[1]}
#解を読みの割り当てとして出力する
#solutions.each{|solution| p solution} #文頭ノードと文末ノード付き
solutions.each{|solution| p solution[0][1..-2]} #解を出力したくない時はこの行をコメントアウト
#nbests.each{|solution| p solution} #制約を考慮する前の解

#解を文字列として出力する
#solutions.each{|solution| puts solution[0][1..-2].inject(""){|str, node| str << node.word}}

#コスト付き読みの割り当てグラフと解を指定したディレクトリにDOT言語で出力
  if @output_directory != nil
    if not Dir.exists?(@output_directory) then Dir.mkdir(@output_directory) end
    File.write("#{@output_directory}/lattice.dot",@lattice.to_dot)
    solutions.each_with_index do |solution,i|
      File.write("#{@output_directory}/solution#{i+1}.dot",@lattice.path_to_dot(solution[0]))
    end
  end
end

end
