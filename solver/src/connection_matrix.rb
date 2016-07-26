
#連接コスト行列を表すクラス
class ConnectionMatrix
  
  #コンストラクタ
  #MeCabなどと同じフォーマットのバイナリファイルを読み込む。
  #
  #テキストファイル(matrix.def)のフォーマット
  #１行目に"右文脈IDのサイズN 左文脈IDのサイズM"
  #２行目以降のN*M行#"右文脈ID 左文脈ID 連接コスト"
  #単語A,Bが連接するとき、Aの右文脈IDとBの左文脈IDを見る。
  #
  #バイナリファイル(matrix.bin)のフォーマット
  #N(符号なし2バイト整数)M(符号なし2バイト整数)連接コスト(符号つき２バイト整数がN*M個)
  #右文脈IDがi、左文脈IDがjの連接コストをC_ijとすると
  #C_00,C_10,C_20,...,C_(N-1)0,C_01,...,C_0(M-1),...,C_(N-2)(M-1),C_(N-1)(M-1)
  #
  #@param [String] filename 連接コストが定義されたバイナリファイルの名前
  def initialize(filename)
    @binary = File.binread(filename)
    @right_size = @binary[0..1].unpack("S*").first
    @left_size = @binary[2..3].unpack("S*").first
  end
  
  #連接コスト
  #@param [Integer] right_id 右文脈ID
  #@param [Integer] left_id 左文脈ID
  #@return [Integer] 連接コスト
  def cost(right_id,left_id)
    n = left_id*@right_size + right_id + 2
    i = n*2
    return @binary[i..i+1].unpack("s*").first
  end
end

