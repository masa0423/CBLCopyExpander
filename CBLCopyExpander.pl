#! /usr/local/bin/perl
############################################################
# 
# CBLCopyExpander.pl
# 
# �T�v�FCOBOL COPY��W�J�c�[��
#       �ȉ��̃x���_�[�ɑΉ�
#       Fujitsu, Hitachi, IBM, Microfocus, HP
# �g�p���@�Fperl CBLCopyExpander.pl sourcedir copydir outdir copyext
# �g�p��  �Fperl CBLCopyExpander.pl C:\src\ C:\cpy\ c:\out cbl
# �ύX�����F2017/04/01 ����
# 
############################################################
#
#
# �g�p���镶���G���R�[�h�ݒ�
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

my $meta_flag = 1;       # META COBOL�̏ꍇ�Ő擪�ɍs�ԍ����Ȃ��ꍇ�ɑΉ�����I�v�V����
my $g_search_folder;     # ��1�����F���ފi�[�t�H���_
my $g_copy_folder;       # ��2�����FCOPY��i�[�t�H���_
my $g_copy_file_ext;     # ��3�����F�W�J��\�[�X�i�[�t�H���_
my $g_result_folder;     # ��4�����FCOPY��g���q

# ���s
&main();

# �v���O�������C������
sub main{
	# �����̐��̃`�F�b�N
	if (@ARGV != 4){
		print "[Error] Usage : perl CBLCopyExpander.pl sourcedir copydir outdir copyext\n";
		exit(1);
	}
	
	# �����擾
	$g_search_folder  = $ARGV[0];
	$g_copy_folder    = $ARGV[1];
	$g_result_folder  = $ARGV[2];
	$g_copy_file_ext  = $ARGV[3];

	# �f�B���N�g�����g����
	$g_search_folder = &trimdirpath($g_search_folder);
	$g_copy_folder   = &trimdirpath($g_copy_folder);
	$g_result_folder = &trimdirpath($g_result_folder);

	# �\�[�X�R�[�h�i�[�f�B���N�g�����̃t�@�C�����̈ꗗ���擾
	my @dir_files = &getfilelist($g_search_folder);
	
	# �e�t�@�C���ɂ���COPY��W�J�����{����
	for ( my $i=0; $i <= $#dir_files; $i++ ) {
	
		# 500�����Ƃɐi���󋵂��o��
		#if($i % 500 == 0){
		#	print "[Info] " . $i . " / " . $#dir_files . "\n";
		#}
		
		# �Ώۃt�@�C���I�[�v��
		my $filename = $g_search_folder ."/". $dir_files[$i];
		
		# �R�s�[��̓W�J
		my $out_arr = &copy_func2($filename);
		
		# �o�̓t�@�C���I�[�v��
		my $result_file = $g_result_folder ."/". $dir_files[$i];
		open(OUT, ">", $result_file);
		
		# �R�s�[��W�J��̓��e���o��
		print OUT join("\n", @$out_arr) . "\n";
		
		# �o�̓t�@�C���N���[�Y
		close(OUT);
	}
	exit;
}

# �R�s�[��̓W�J
sub copy_func2{
	my ($_fname,$_djoin,$_join,$_fixset,$_rep_by,$_rep_to) = @_;
	my @source_line = getFileContent($_fname);
	
	# ���v���C�X���w�肳��Ă��邩�ǂ���
	my $isreplace = 0;
	if($#$_rep_by>=0 && $#$_rep_to>=0 ){
		$isreplace = 1;
	}
	
	# JOIN,DISJOIN���w�肳��Ă��邩�ǂ���
	my $isjoin = 0;
	if($#$_djoin>=0 && $#$_join>=0 && $_fixset ne  "" ){
		$isjoin = 1;
	}
	
	# �o�͗p�z��(�I�[�͉��s�Ȃ�)
	my @out_arr = ();
	# ���݂�DIVISION��\���B
	# �W�J���ׂ��łȂ�DIV�ɋL�q����Ă���COPY��̏ꍇ�ɑΏ�
	my $cur_div = DIV_OTHE;
	
	# �t�@�C����1�s���ǂݍ���
	for(my $j=0; $j<=$#source_line; $j++){
		my $data_line = Encode::decode("cp932", $source_line[$j]); 
		$data_line=~s/(:?\r\n|\n)$//g;
		
		# META COBOL�̃I�v�V�����ŁA�擪�ɍs�ԍ�6�P�^��t�^����I�v�V����
		if($meta_flag){
			$data_line = "      " . $data_line;
		}
		
		# ���v���C�X���s
		if($isreplace){
			# ��A�ԍ��̈��u�����Ȃ��悤�ɁA���O�ɐ؂蕪������B
			my $tmp_others = substr($data_line, 6);
			
			for(my $r=0;$r<=$#$_rep_to;$r++){
				# \Q-\E�̓G�X�P�[�v�Bquotemeta�ł��悢.
				$tmp_others=~s/\Q$$_rep_to[$r]\E/$$_rep_by[$r]/g;
				# �u���㕶����Ɉ�A�ԍ��̈������B
				$data_line = substr($data_line, 0, 6) . $tmp_others;
			}
		}
		
		# �R�����g�s�̏ꍇ(�f�o�b�O�s�͓W�J���Ȃ�)
		if ($data_line=~m/^.{6}[\*|\/|D]{1}/) {
			push (@out_arr, $data_line);
			next;
		}
		
		# DIVISION�̎擾
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
		
		# ���s�폜
		my $tmp_line = &trimLine($data_line);
		
		# �����񃊃e������u������
		my $literal_arr_ref; #���e�����i�[�z��̃��t�@�����X
		($tmp_line, $literal_arr_ref) = &extract_literal($tmp_line);
		
		
		# 20160511_META COBOL�Ή�
		if ($tmp_line=~m/\s\+\+INCLUDE\s/) {
			$tmp_line=~s/\s\+\+INCLUDE\s/ COPY      /g;
			# �I�[�Ƀs���I�h�t�^�B++INCLUDE�̓s���I�h������Ȃ����߁A�I�[������ł��Ȃ�����B
			$tmp_line.= ".";
		}
		
		# COPY��ł͂Ȃ��ꍇ
		if ($tmp_line !~ m/\sCOPY\s/g ) {
			# �T�t�B�b�N�X�^�v���t�B�b�N�X�u��
			if ( $isjoin == 1 ) {
				my $replacedstr = &replacePrefixSuffix($data_line,$_djoin,$_join,$_fixset);
				push (@out_arr, $replacedstr);
			}else{
				# ���ڒ�`�ȊO�͒u�����Ȃ�
				push (@out_arr, $data_line);
			}
			next;
		}
		
		# �����ɓ��B�����ꍇ�ACOPY��
		
		# IDENTIFICATION DIV, ENVIRONMENT DIV�ɏ�����Ă���COPY��̏ꍇ�͓W�J���Ȃ�
		if($cur_div == DIV_IDEN || $cur_div == DIV_ENVI ){
			next;
		}
		
		# �������R�����g�A�E�g���ďo��
		push (@out_arr, &toCommentLine($data_line));
		
		# COPY��ȑO�ɋL�q������ΐ؂�o���ďo��
		my @temparr = split(/\sCOPY\s/, $tmp_line);
		if($temparr[0]!~/^.{6}\s*$/){
			# �����񃊃e�����𕜊�������
			if($#$literal_arr_ref+1 !=0){
				my $total_line= join("\\n",@temparr);
				$total_line = &restore_literal($total_line,$literal_arr_ref);
				@temparr = split(/\\n/, $total_line);
			}
			# COPY�ȑO�̏o��( 01 XXXX. COPY YYYY.  ->  01 XXXX.            )
			push (@out_arr, $temparr[0]);
			# COPY��s�̏o��( 01 XXXX. COPY YYYY.  -> *COPY YYYY.          )
			$tmp_line = "       COPY " . $temparr[1];
			push (@out_arr, &toCommentLine($tmp_line));
		}else{
			# �����񃊃e�����𕜊�������
			if($#$literal_arr_ref+1 != 0){
				$tmp_line = &restore_literal($tmp_line,$literal_arr_ref);
			}
		}
		
		# �����s�ɂ킽��COPY��̏ꍇ�A�S�ʂ��擾
		if(!&isdot($tmp_line)){
			$j++;
			for(; $j<=$#source_line; $j++){
				my $data_line2 = Encode::decode("cp932", $source_line[$j]); 
				$data_line2=~ s/(:?\r\n|\n)$//g;
				
				# META COBOL�̃I�v�V�����ŁA�擪�ɍs�ԍ�6�P�^��t�^����I�v�V����
				if($meta_flag){
					$data_line2 = "      " . $data_line2;
				}
		
				push (@out_arr, &toCommentLine($data_line2));
				if ($data_line2=~m/^.{6}[\*|\/|D]{1}/) {
					next;
				}
				# ���s�폜
				$data_line2 = &trimLine($data_line2);
				# 
				$data_line2=~s/^.{6}\s(.*)/$1/g;
				# ���ߍ���
				$tmp_line .= $data_line2;
				
				# �h�b�g���o�Ă�����擾�I��
				if(&isdot($tmp_line)){
					last;
				}
			}
		}
		
		# �Ăу��e�����̒u��
		($tmp_line, $literal_arr_ref) = &extract_literal($tmp_line);
		
		# COPY��̎��o��
		$tmp_line=~s/.*\s(COPY\s.*?)\..*$/$1 /g;
		# COPY��ȍ~�ɖ��߂͌���R�����g������
		
		# �Ăу��e�����̒u���߂�
		if($#$literal_arr_ref+1 != 0){
			$tmp_line = &restore_literal($tmp_line,$literal_arr_ref);
		}
			
			
		# COPY��\�����
		my ($copyname, $o_djoin, $o_join, $o_fixset, $o_rep_by, $o_rep_to) = &parseCOPYKU($tmp_line);
		
		my $copy_fullname = $g_copy_folder."/".$copyname;
		# COPY�X�e�[�g�����g�Ŏw�肳�ꂽCOPY�喼�Ɋg���q���܂܂�Ă��Ȃ��ꍇ�A�g���q��t�^
		if( $copyname !~ m/\./ ){
			$copy_fullname = $copy_fullname . "." . $g_copy_file_ext;
		}
		
		# COPY��̓W�J
		if ( -f $copy_fullname ) {
			my $tmp_out_arr = &copy_func2($copy_fullname, $o_djoin, $o_join, $o_fixset, $o_rep_by, $o_rep_to);
			push(@out_arr,@$tmp_out_arr);
		}else{
			my $line_number = $j+1;
			print "[Error] COPY file does not exist. COPY=". $copyname . " SOURCE=" . $_fname . " LINE=" . $line_number. "\n";
		}
	}
	
	# �W�J����e��Ԃ�
	return \@out_arr;
}

# �f�B���N�g������S�v���O�������ǂݍ���
# �J�����g�f�B���N�g���A���[�g�f�B���N�g���͏��O
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

# �s�𐮂���
sub trimLine{
	my $line = shift;
	#���s�폜
	$line=~ s/(:?\r\n|\n)$//g;
	#72�J�����ڈȍ~�͐؂�̂�
	$line=cut72($line);
	#�s���R�����g�폜
	$line=~ s/(^.{6}.*)\*>.*/$1/g;
	$line=~ s/(^.{6}.*)\/\*.*/$1/g;    # MAETA COBOL
	#�I�[�ɃX�y�[�X��t�^
	$line.=" ";
	return  $line;
}

#�I�[�h�b�g�̗L�����m�F����B
#�����_�ɂ̓q�b�g���Ȃ��d�l�B
sub isdot{
	my $str = shift;
	$str=~s/\d+\.\d+//g;
	$str=~s/:[a-zA-Z_0-9\-]+\.[a-zA-Z_0-9\-]+//g; #SQL
	if($str=~/\./){
		return 1;
	}
	return 0;
}

#72byte������ꍇ�͐؂�̂Ă�
sub cut72{
	my $line = shift;
    my $count_all = length(Encode::encode('cp932',$line));
	#�I�[�X�y�[�X����
	if($count_all>72){
    	my $count_zen= $count_all- length($line);
		$line = substr($line,0,72-$count_zen);
	}
	return $line;
}

#�����񒆂Ɋ܂܂��'',""�ŕ\������郊�e������z��ɒ��o�B
#�����񒆂Ɋ܂܂�郊�e������LITERAL�ɒu�����ԋp
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

#extract_literal�Œu���������e���������ɖ߂��B
#�Ҕ��̔z��ƁA�����񒆂̒u���������e����(LITERAL)�̐�����v���Ȃ��ꍇ�G���[�ƂȂ�
sub restore_literal {
	my ($line, $literal_arr_ref) = @_;
	for(my $k=0;$k<=$#$literal_arr_ref;$k++){
		my $literal = $$literal_arr_ref[$k];
		if($line=~m/[\s|N|X|C|K|=|\(|,]LITERAL[\s|\.|\)|,]/g){
			#g�I�v�V���������Ă͂����Ȃ�
			$line=~s/([\s|N|X|C|K|=|\(|,])LITERAL([\s|\.|\)|,])/$1$literal$2/;
		}else{
			die "[Error] literal restore failed. : ".$line ."\t".$literal."\n";
		}
	}
	return $line;
}

#�t�@�C����z��ɓǂݍ���
sub getFileContent{
	my $filename = shift;
	open( IN, "<", "$filename" ) || die "[Error]: $filename:$!\n";
	my @source_line = <IN>;
	close(IN);
	return @source_line;
}

#������̐擪7�����ڂ�*�ɂ���(�R�����g��)
sub toCommentLine{
	my $line = shift;
	$line=~ s/(^.{6}).{1}(.*$)/$1\*$2/g;
	return $line;
}
#������̐擪7�����ڂ𔼊pSP�ɂ���(�A�N�e�B�u��)
sub toActiveLine{
	my $line = shift;
	$line=~ s/(^.{6}).{1}(.*$)/$1 $2/g;
	return $line;
}

# �T�t�B�b�N�X�^�v���t�B�b�N�X�u��
sub replacePrefixSuffix{
	my ($data_line,$_djoin,$_join,$_fixset) = @_;
	my $ret="";
	
	# ���ڒ�`�̕ϐ����݂̂ɓK�p����
	if( $data_line=~m/^(.{6}.\s*\d+\s+)(\S+)([\s|\.].*)$/){
		my $def_before = $1;
		my $def_vname = $2;
		my $def_after = $3;
		
		# �I�[Dot���폜
		my $dotflg=0;
		if(&isdot($def_vname)){
			$def_vname=~s/\.$//g;
			$dotflg=1;
		}
		# �T�t�B�b�N�X�^�v���t�B�b�N�X�u��
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
		# Dot��t�^
		if($dotflg){
			$def_vname.=".";
		}
		$ret = $def_before.$def_vname.$def_after
	}else{
		$ret = $data_line;
	}
	return $ret;
}

# COPY��\�����
sub parseCOPYKU{
	my $line = shift;   # �R�s�[����܂ޕ�����
	my $copyname = "";  # �R�s�[��̃t���p�X
	my @o_djoin  = ();  # DISJOINING�w�薼
	my @o_join   = ();  # JOINING�w�薼
	my $o_fixset = "";  # PREFIX or SUFFIX. �R���X�^���g�l�Ŏw��
	my @o_rep_by = ();  # REPLACE�� �u���㕶����
	my @o_rep_to = ();  # REPLACE�� �u���O������
	
	if($line=~ /^COPY\s+(\S+)\s+(.*)\z/g){
		$copyname = $1;
		$copyname=~ s/['|"]//g;
		my $option = " " .$2." ";
		my @retnum = ();
		
		# DISJOINING�̔��o���B
		@retnum = $option=~ m/\sDISJOINING\s+(\S+)\s/g;
		if($#retnum>=0){
			push (@o_djoin, @retnum);
		}
		
		@retnum = ();
		# JOINING�̔��o���B
		@retnum = $option=~ m/\sJOINING\s+(\S+)\s/g;
		if($#retnum>=0){
			push (@o_join, @retnum);
		}
		
		# DISJOINING/JOINING�������܂܂�Ă����ꍇ�A
		# �ʂɈႤPREFIX/SUFFIX�I�v�V�������w�肳��Ă��邱�Ƃ͂Ȃ��Ƃ��ď�����i�߂�B
		# �ŏ����������Ĕ��f����.
		if($option=~ m/\sPREFIX\s/){
			$o_fixset = OPT_PREFIX;
		}else{
			$o_fixset = OPT_SUFFIX;
		}
		
		if($option=~ m/^\s+REPLACING\s+(.*)$/){
			my $tmpstr = $1;
			
			# ==�ň͂܂�镶������̃X�y�[�X���ꎞ�I�ɒu������ƂƂ��ɁA==���O���B
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
			
			# �X�J���[�R���e�L�X�g�}�b�`���O�Ŏ擾
			while ($tmpstr =~m/(.*?)\s+BY\s+(.*?)\s+/g ) {
				my $tmp_o_rep_to = $1;
				my $tmp_o_rep_by = $2;
				
				# �O��X�y�[�X�g����
			    $tmp_o_rep_to=~s/^\s*(\S+)\s*$/$1/g;
			    $tmp_o_rep_by=~s/^\s*(\S+)\s*$/$1/g;
			    
			    # ==�X�y�[�X�߂�
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

# �f�B���N�g���̏I�[��\���Ȃ��ꍇ�t�^
# \�����ׂ�/�ɒu��
sub trimdirpath{
	my $path = shift;
	$path=~ s/\\/\//g;
	$path=~ s/\/$//g;
	return $path;
}