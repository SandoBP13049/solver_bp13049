各ディレクトリの説明

ans
自分と新井さんの解答結果、正解

arai
ma11011新井侑太「制約充足による手書き変体仮名認識」のプログラム
src/command/solve.rbを読みの割り当てを出力して終了するように改変している
src/csp/normalizer.rbをCSPの以下の拡張に対応するように改変している
csp{ ...., :odoriji=>{ Symbol=>Array<Symbol,Integer>}}
Symbol=>Array<Symbol,Integer>は踊り字の変数と、その踊り字があった位置との対応
変数x1_1が踊り字で、踊り字が変数x1_0の領域の2番目にあった場合
{ :x1_1=>[:x1_0, 2]}

csp
翻刻制約充足問題
新井さんのcspとの変更点:な{ ら,く}ら{ く,ん}に; -> な{ ら,く}{ な,ら}{ く,ん}に; (我ならなくに)

dic
辞書データと辞書作成に関するプログラム
lex.csv:中古和文UniDicの単語データ
matrix.bin:中古和文UniDicの連接コスト行列のバイナリデータ
ise2_dic.csv:ise2.dbと対応する単語をUniDicから抜き出したもの
memo.txt:UniDicにない単語など色々メモ
*.db:新井さんのプログラムで使用する辞書
*.csv:自分のプログラムで使用する古い形式の辞書
*_da.txt:DoubleArrayの構築に使用する辞書
*_da_rev.txt:逆引き用DoubleArrayの構築に使用する辞書
*_saved.txt:保存したDoubleArray
build_da.rb:DoubleArrayを構築して保存する
cut_for_rs.rb:新井さんの辞書のシードとして使用できる形に変換する
extract.rb:ひらがなと漢字からなる単語を抽出、漢字はひらがなに直し濁点を取り除く
group_dic.rb:同じ単語(文字列)を1行にまとめる
rand_ext.rb:ランダムに単語を抽出しソートする
reverse_and_sort.rb:単語を反転させた後ソートする
sort_and_cut.rb:ソートし先頭から5要素(文字列,左文脈id,右文脈id,生起コスト,品詞)を残す
unique.rb:重複している単語(文字列と文脈idが同じ)があれば生起コストが最小のものを残す

doc
プログラムのドキュメント

ise2_jtk_old
字典かなを使用した画像認識結果から作成したテキスト形式のCSPの記述

ise2ans_jtk_old
ise2csp_jtk_oldの各αの値での解答結果、正解

ise2csp_jtk_old
ise2_jtk_oldをCSPに変換したもの

reading
ise2.dbで作成した読みの割り当てグラフのノード

reading_uni
unidic.dbで作成した読みの割り当てグラフのノード

src
プログラム

util
実験の補助やデータ整理のためのプログラム


実行環境
ruby2.0以上
新井さんのプログラムに必要なもの:sqlite3
自分のプログラムに必要なもの:depq

翻刻制約充足問題、読みの割り当てグラフ、読みの割り当て結果の視覚化にはGraphvizが必要
ドキュメント生成にはyardが必要

使い方
config.txtに以下を記述する。config.txtはsrcがあるディレクトリに置く。
絶対パス、またはカレントディレクトリからの相対パス
1行目:辞書
2行目:連接コスト行列
3行目:保存されたDoubleArray
4行目:保存された逆引き用DoubleArray

辞書を作成する:
古い形式の辞書の場合:
%ruby extract.rb lex.csv tmp1.csv
%ruby sort_and_cut.rb tmp1.csv tmp2.csv
%ruby unique.rb tmp2.csv unidic.csv
DoubleArray用辞書の場合:
%ruby extract.rb lex.csv tmp1.csv
%ruby sort_and_cut.rb tmp1.csv tmp2.csv
%ruby unique.rb tmp2.csv tmp3.csv
%ruby group_dic.rb tmp3.csv unidic_da.txt
%ruby build_da.rb unidic_da.txt unidic_da_saved.txt

問題を解く:
%ruby solve.rb csp [options]
csp:翻刻制約充足問題のファイル
    -n n
    -d, --dictionary dictionary
    -r, --reading reading
    -m, --matrix matrix
    -a, --da double_array
    -b, --dar double_array_revarse
    -o, --output output_directory
n:N-best探索のN 指定しない場合は1
dictionary:古い形式の辞書 指定しない場合はconfig.txtに書かれているものを使用する
reading:読みの割り当てグラフのノード(新井さんのプログラムで作成)
matrix:連接コスト行列 指定しない場合はconfig.txtに書かれているものを使用する
double_array:保存したDoubleArray 指定しない場合はconfig.txtに書かれているものを使用する
double_array_revarse:保存した逆引き用DoubleArray 指定しない場合はconfig.txtに書かれているものを使用する
output_directory:指定した場合はディレクトリoutput_directoryを作成し、output_directory下にDOT言語で記述されたコスト付き読みの割り当てグラフと各解を作成する

解や計算時間は標準出力に出力するのでsolve.rbを編集して調整する

解答を採点する:
%ruby mark.rb csp right_answer answer (n)
csp:翻刻制約充足問題のファイル
right_answer:正解のファイル
answer:採点する解答のファイル
n:指定した場合はanswerの上からn個の解答を採点する

ドキュメント生成
%yard doc src/*.rb src/rs/*.rb dic/*.rb -r readme.txt 
