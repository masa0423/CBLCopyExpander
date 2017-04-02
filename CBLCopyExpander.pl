#! /usr/local/bin/perl
############################################################
# 
# CBLCopyExpander.pl
# 
# 概要：COBOL COPY句展開ツール
#       以下のベンダーに対応
#       Fujitsu, Hitachi, IBM, Microfocus, HP
# 使用方法：perl CBLCopyExpander.pl sourcedir copydir outdir copyext
# 使用例  ：perl CBLCopyExpander.pl C:\src\ C:\cpy\ c:\out cbl
# 変更履歴：2017/04/01 初版
# 
############################################################
#
#
# 使用する文字エンコード設定
use encoding "shiftjis";
use open OUT => ":encoding(cp932)";
binmode(STDERR, ":encoding(shiftjis)");
use Encode 'decode', 'encode';
use strict;

use constant {
	OPT_PREFIX => 0,
	OPT_SUFFIX => 1,
};
use constant {
	DIV_IDEN => 0,
	DIV_ENVI => 1,
	DIV_DATA => 2,
	DIV_PROC => 3,
	DIV_OTHE => 4,
};

my $meta_flag = 1;       # META COBOLの場合で先頭に行番号がない場合に対応するオプション
my $g_search_folder;     # 第1引数：資材格納フォルダ
my $g_copy_folder;       # 第2引数：COPY句格納フォルダ
my $g_copy_file_ext;     # 第3引数：展開後ソース格納フォルダ
my $g_result_folder;     # 第4引数：COPY句拡張子

# 実行
&main();

# プログラムメイン処理
sub main{
	# 引数の数のチェック
	if (@ARGV != 4){
		print "[Error] Usage : perl CBLCopyExpander.pl sourcedir copydir outdir copyext\n";
		exit(1);
	}
	
	# 引数取得
	$g_search_folder  = $ARGV[0];
	$g_copy_folder    = $ARGV[1];
	$g_result_folder  = $ARGV[2];
	$g_copy_file_ext  = $ARGV[3];

	# ディレクトリ名トリム
	$g_search_folder = &trimdirpath($g_search_folder);
	$g_copy_folder   = &trimdirpath($g_copy_folder);
	$g_result_folder = &trimdirpath($g_result_folder);

	# ソースコード格納ディレクトリ中のファイル名の一覧を取得
	my @dir_files = &getfilelist($g_search_folder);
	
	# 各ファイルについてCOPY句展開を実施する
	for ( my $i=0; $i <= $#dir_files; $i++ ) {
	
		# 500件ごとに進捗状況を出力
		#if($i % 500 == 0){
		#	print "[Info] " . $i . " / " . $#dir_files . "\n";
		#}
		
		# 対象ファイルオープン
		my $filename = $g_search_folder ."/". $dir_files[$i];
		
		# コピー句の展開
		my $out_arr = &copy_func2($filename);
		
		# 出力ファイルオープン
		my $result_file = $g_result_folder ."/". $dir_files[$i];
		open(OUT, ">", $result_file);
		
		# コピー句展開後の内容を出力
		print OUT join("\n", @$out_arr) . "\n";
		
		# 出力ファイルクローズ
		close(OUT);
	}
	exit;
}

# コピー句の展開
sub copy_func2{
	my ($_fname,$_djoin,$_join,$_fixset,$_rep_by,$_rep_to) = @_;
	my @source_line = getFileContent($_fname);
	
	# リプレイスが指定されているかどうか
	my $isreplace = 0;
	if($#$_rep_by>=0 && $#$_rep_to>=0 ){
		$isreplace = 1;
	}
	
	# JOIN,DISJOINが指定されているかどうか
	my $isjoin = 0;
	if($#$_djoin>=0 && $#$_join>=0 && $_fixset ne  "" ){
		$isjoin = 1;
	}
	
	# 出力用配列(終端は改行なし)
	my @out_arr = ();
	# 現在のDIVISIONを表す。
	# 展開すべきでないDIVに記述されているCOPY句の場合に対処
	my $cur_div = DIV_OTHE;
	
	# ファイルを1行ずつ読み込む
	for(my $j=0; $j<=$#source_line; $j++){
		my $data_line = Encode::decode("cp932", $source_line[$j]); 
		$data_line=~s/(:?\r\n|\n)$//g;
		
		# META COBOLのオプションで、先頭に行番号6ケタを付与するオプション
		if($meta_flag){
			$data_line = "      " . $data_line;
		}
		
		# リプレイス実行
		if($isreplace){
			# 一連番号領域を置換しないように、事前に切り分けする。
			my $tmp_others = substr($data_line, 6);
			
			for(my $r=0;$r<=$#$_rep_to;$r++){
				# \Q-\Eはエスケープ。quotemetaでもよい.
				$tmp_others=~s/\Q$$_rep_to[$r]\E/$$_rep_by[$r]/g;
				# 置換後文字列に一連番号領域をつける。
				$data_line = substr($data_line, 0, 6) . $tmp_others;
			}
		}
		
		# コメント行の場合(デバッグ行は展開しない)
		if ($data_line=~m/^.{6}[\*|\/|D]{1}/) {
			push (@out_arr, $data_line);
			next;
		}
		
		# DIVISIONの取得
		if ($data_line=~m/^.{6}\s(\S+)\s+DIVISION.*/g){
			my $tmp_div = $1;
			if( ($tmp_div eq "ID" || $tmp_div eq "IDENTIFICATION" || $tmp_div eq "\ID") ){
				$cur_div = DIV_IDEN;
			}elsif( $tmp_div eq "EMVIRONMENT" || $tmp_div eq "\ED"){
				$cur_div = DIV_ENVI;
			}elsif( $tmp_div eq "DATA" || $tmp_div eq "\DD" ){
				$cur_div = DIV_DATA;
			}elsif( $tmp_div eq "PROCEDURE" ){
				$cur_div = DIV_PROC;
			}else{
			}
		}
		
		# 改行削除
		my $tmp_line = &trimLine($data_line);
		
		# 文字列リテラルを置換する
		my $literal_arr_ref; #リテラル格納配列のリファレンス
		($tmp_line, $literal_arr_ref) = &extract_literal($tmp_line);
		
		
		# 20160511_META COBOL対応
		if ($tmp_line=~m/\s\+\+INCLUDE\s/) {
			$tmp_line=~s/\s\+\+INCLUDE\s/ COPY      /g;
			# 終端にピリオド付与。++INCLUDEはピリオドが伴わないため、終端が判定できないから。
			$tmp_line.= ".";
		}
		
		# COPY句ではない場合
		if ($tmp_line !~ m/\sCOPY\s/g ) {
			# サフィックス／プレフィックス置換
			if ( $isjoin == 1 ) {
				my $replacedstr = &replacePrefixSuffix($data_line,$_djoin,$_join,$_fixset);
				push (@out_arr, $replacedstr);
			}else{
				# 項目定義以外は置換しない
				push (@out_arr, $data_line);
			}
			next;
		}
		
		# ここに到達した場合、COPY句
		
		# IDENTIFICATION DIV, ENVIRONMENT DIVに書かれているCOPY句の場合は展開しない
		if($cur_div == DIV_IDEN || $cur_div == DIV_ENVI ){
			next;
		}
		
		# 原文をコメントアウトして出力
		push (@out_arr, &toCommentLine($data_line));
		
		# COPY句以前に記述があれば切り出して出力
		my @temparr = split(/\sCOPY\s/, $tmp_line);
		if($temparr[0]!~/^.{6}\s*$/){
			# 文字列リテラルを復活させる
			if($#$literal_arr_ref+1 !=0){
				my $total_line= join("\\n",@temparr);
				$total_line = &restore_literal($total_line,$literal_arr_ref);
				@temparr = split(/\\n/, $total_line);
			}
			# COPY以前の出力( 01 XXXX. COPY YYYY.  ->  01 XXXX.            )
			push (@out_arr, $temparr[0]);
			# COPY句行の出力( 01 XXXX. COPY YYYY.  -> *COPY YYYY.          )
			$tmp_line = "       COPY " . $temparr[1];
			push (@out_arr, &toCommentLine($tmp_line));
		}else{
			# 文字列リテラルを復活させる
			if($#$literal_arr_ref+1 != 0){
				$tmp_line = &restore_literal($tmp_line,$literal_arr_ref);
			}
		}
		
		# 複数行にわたるCOPY句の場合、全量を取得
		if(!&isdot($tmp_line)){
			$j++;
			for(; $j<=$#source_line; $j++){
				my $data_line2 = Encode::decode("cp932", $source_line[$j]); 
				$data_line2=~ s/(:?\r\n|\n)$//g;
				
				# META COBOLのオプションで、先頭に行番号6ケタを付与するオプション
				if($meta_flag){
					$data_line2 = "      " . $data_line2;
				}
		
				push (@out_arr, &toCommentLine($data_line2));
				if ($data_line2=~m/^.{6}[\*|\/|D]{1}/) {
					next;
				}
				# 改行削除
				$data_line2 = &trimLine($data_line2);
				# 
				$data_line2=~s/^.{6}\s(.*)/$1/g;
				# ため込み
				$tmp_line .= $data_line2;
				
				# ドットが出てきたら取得終了
				if(&isdot($tmp_line)){
					last;
				}
			}
		}
		
		# 再びリテラルの置換
		($tmp_line, $literal_arr_ref) = &extract_literal($tmp_line);
		
		# COPY句の取り出し
		$tmp_line=~s/.*\s(COPY\s.*?)\..*$/$1 /g;
		# COPY句以降に命令は現状コメント化する
		
		# 再びリテラルの置換戻し
		if($#$literal_arr_ref+1 != 0){
			$tmp_line = &restore_literal($tmp_line,$literal_arr_ref);
		}
			
			
		# COPY句構文解析
		my ($copyname, $o_djoin, $o_join, $o_fixset, $o_rep_by, $o_rep_to) = &parseCOPYKU($tmp_line);
		
		my $copy_fullname = $g_copy_folder."/".$copyname;
		# COPYステートメントで指定されたCOPY句名に拡張子が含まれていない場合、拡張子を付与
		if( $copyname !~ m/\./ ){
			$copy_fullname = $copy_fullname . "." . $g_copy_file_ext;
		}
		
		# COPY句の展開
		if ( -f $copy_fullname ) {
			my $tmp_out_arr = &copy_func2($copy_fullname, $o_djoin, $o_join, $o_fixset, $o_rep_by, $o_rep_to);
			push(@out_arr,@$tmp_out_arr);
		}else{
			my $line_number = $j+1;
			print "[Error] COPY file does not exist. COPY=". $copyname . " SOURCE=" . $_fname . " LINE=" . $line_number. "\n";
		}
	}
	
	# 展開後内容を返す
	return \@out_arr;
}

# ディレクトリから全プログラム名読み込み
# カレントディレクトリ、ルートディレクトリは除外
sub getfilelist{
	my $directory = shift;
	opendir DIR, $directory or die "$directory:$!";
	my @ret = readdir(DIR);
	closedir(DIR);
	while ($ret[0] eq '.' || $ret[0] eq '..'){
		shift @ret;
	}
	return @ret;
}

# 行を整える
sub trimLine{
	my $line = shift;
	#改行削除
	$line=~ s/(:?\r\n|\n)$//g;
	#72カラム目以降は切り捨て
	$line=cut72($line);
	#行内コメント削除
	$line=~ s/(^.{6}.*)\*>.*/$1/g;
	$line=~ s/(^.{6}.*)\/\*.*/$1/g;    # MAETA COBOL
	#終端にスペースを付与
	$line.=" ";
	return  $line;
}

#終端ドットの有無を確認する。
#小数点にはヒットしない仕様。
sub isdot{
	my $str = shift;
	$str=~s/\d+\.\d+//g;
	$str=~s/:[a-zA-Z_0-9\-]+\.[a-zA-Z_0-9\-]+//g; #SQL
	if($str=~/\./){
		return 1;
	}
	return 0;
}

#72byte超える場合は切り捨てる
sub cut72{
	my $line = shift;
    my $count_all = length(Encode::encode('cp932',$line));
	#終端スペース調整
	if($count_all>72){
    	my $count_zen= $count_all- length($line);
		$line = substr($line,0,72-$count_zen);
	}
	return $line;
}

#文字列中に含まれる'',""で表現されるリテラルを配列に抽出。
#文字列中に含まれるリテラルはLITERALに置換し返却
sub extract_literal {
	my $line = shift;
	my @literal_arr = ();
	{
		my $literal_flg=0;
		
		while ($line=~ m/[\s|N|X|C|K|=|\(|,](['|"].*?['|"])[\s|\.|\)|,]/go){
			push (@literal_arr, $1);
			$literal_flg=1;
		}
		if($literal_flg){
			$line=~ s/([\s|N|X|C|K|=|\(|,])['|"].*?['|"]([\s|\.|\)|,])/$1LITERAL$2/go;
		}
	}
	return ($line, \@literal_arr);
}

#extract_literalで置換したリテラルを元に戻す。
#待避先の配列と、文字列中の置き換えリテラル(LITERAL)の数が一致しない場合エラーとなる
sub restore_literal {
	my ($line, $literal_arr_ref) = @_;
	for(my $k=0;$k<=$#$literal_arr_ref;$k++){
		my $literal = $$literal_arr_ref[$k];
		if($line=~m/[\s|N|X|C|K|=|\(|,]LITERAL[\s|\.|\)|,]/g){
			#gオプションを入れてはいけない
			$line=~s/([\s|N|X|C|K|=|\(|,])LITERAL([\s|\.|\)|,])/$1$literal$2/;
		}else{
			die "[Error] literal restore failed. : ".$line ."\t".$literal."\n";
		}
	}
	return $line;
}

#ファイルを配列に読み込む
sub getFileContent{
	my $filename = shift;
	open( IN, "<", "$filename" ) || die "[Error]: $filename:$!\n";
	my @source_line = <IN>;
	close(IN);
	return @source_line;
}

#文字列の先頭7文字目を*にする(コメント化)
sub toCommentLine{
	my $line = shift;
	$line=~ s/(^.{6}).{1}(.*$)/$1\*$2/g;
	return $line;
}
#文字列の先頭7文字目を半角SPにする(アクティブ化)
sub toActiveLine{
	my $line = shift;
	$line=~ s/(^.{6}).{1}(.*$)/$1 $2/g;
	return $line;
}

# サフィックス／プレフィックス置換
sub replacePrefixSuffix{
	my ($data_line,$_djoin,$_join,$_fixset) = @_;
	my $ret="";
	
	# 項目定義の変数名のみに適用する
	if( $data_line=~m/^(.{6}.\s*\d+\s+)(\S+)([\s|\.].*)$/){
		my $def_before = $1;
		my $def_vname = $2;
		my $def_after = $3;
		
		# 終端Dotを削除
		my $dotflg=0;
		if(&isdot($def_vname)){
			$def_vname=~s/\.$//g;
			$dotflg=1;
		}
		# サフィックス／プレフィックス置換
		for(my $i = 0; $i <= $#$_djoin; $i++){
			if($_fixset == OPT_PREFIX){
				#if ( $def_vname=~m/^$$_djoin[$i]/g ) {
					$def_vname=~s/^$$_djoin[$i]/$$_join[$i]/g;
				#}
			}else{
				#if ( $def_vname=~m/$$_djoin[$i]$/g ) {
					$def_vname=~s/$$_djoin[$i]$/$$_join[$i]/g;
				#}
			}
		}
		# Dotを付与
		if($dotflg){
			$def_vname.=".";
		}
		$ret = $def_before.$def_vname.$def_after
	}else{
		$ret = $data_line;
	}
	return $ret;
}

# COPY句構文解析
sub parseCOPYKU{
	my $line = shift;   # コピー句を含む文字列
	my $copyname = "";  # コピー句のフルパス
	my @o_djoin  = ();  # DISJOINING指定名
	my @o_join   = ();  # JOINING指定名
	my $o_fixset = "";  # PREFIX or SUFFIX. コンスタント値で指定
	my @o_rep_by = ();  # REPLACE句 置換後文字列
	my @o_rep_to = ();  # REPLACE句 置換前文字列
	
	if($line=~ /^COPY\s+(\S+)\s+(.*)\z/g){
		$copyname = $1;
		$copyname=~ s/['|"]//g;
		my $option = " " .$2." ";
		my @retnum = ();
		
		# DISJOININGの抜出し。
		@retnum = $option=~ m/\sDISJOINING\s+(\S+)\s/g;
		if($#retnum>=0){
			push (@o_djoin, @retnum);
		}
		
		@retnum = ();
		# JOININGの抜出し。
		@retnum = $option=~ m/\sJOINING\s+(\S+)\s/g;
		if($#retnum>=0){
			push (@o_join, @retnum);
		}
		
		# DISJOINING/JOININGが複数含まれていた場合、
		# 個別に違うPREFIX/SUFFIXオプションが指定されていることはないとして処理を進める。
		# 最初だけを見て判断する.
		if($option=~ m/\sPREFIX\s/){
			$o_fixset = OPT_PREFIX;
		}else{
			$o_fixset = OPT_SUFFIX;
		}
		
		if($option=~ m/^\s+REPLACING\s+(.*)$/){
			my $tmpstr = $1;
			
			# ==で囲まれる文字列内のスペースを一時的に置換するとともに、==を外す。
			my $replaced_str = "";
			while( $tmpstr=~m/==(.*?)==\s+BY\s+==(.*?)==/g ){
				my $tmp_to = $1;
				my $tmp_by = $2;
				$tmp_to=~s/\s/SPACEREPLACED/g;
				$tmp_by=~s/\s/SPACEREPLACED/g;
				
				$replaced_str .= $tmp_to . " BY ". $tmp_by ." ";
			}
			if($replaced_str ne ""){
				$tmpstr = $replaced_str;
			}
			
			# スカラーコンテキストマッチングで取得
			while ($tmpstr =~m/(.*?)\s+BY\s+(.*?)\s+/g ) {
				my $tmp_o_rep_to = $1;
				my $tmp_o_rep_by = $2;
				
				# 前後スペーストリム
			    $tmp_o_rep_to=~s/^\s*(\S+)\s*$/$1/g;
			    $tmp_o_rep_by=~s/^\s*(\S+)\s*$/$1/g;
			    
			    # ==スペース戻し
				$tmp_o_rep_to=~s/SPACEREPLACED/ /g;
				$tmp_o_rep_by=~s/SPACEREPLACED/ /g;
				
				push (@o_rep_to, $tmp_o_rep_to);
				push (@o_rep_by, $tmp_o_rep_by);
			}
		}
	}else{
		die "[Error] COPY file parse failed. : ".$copyname . "\t" . $line ."\n";
	}
	
	return ($copyname, \@o_djoin, \@o_join, $o_fixset, \@o_rep_by, \@o_rep_to);
}

# ディレクトリの終端に\がない場合付与
# \をすべて/に置換
sub trimdirpath{
	my $path = shift;
	$path=~ s/\\/\//g;
	$path=~ s/\/$//g;
	return $path;
}