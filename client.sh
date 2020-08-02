#! /bin/bash

let login_state=1
client_path=$(cd $(dirname $0); pwd)

while [ $login_state == 1 ]
do
	login=$(zenity  --username --password --ok-label="登录" --cancel-label="退出" --title "登录到作业系统")
	if [ $? != 0 ]
	then
		exit 0
	fi
	username=$(echo $login | cut -d'|' -f1)
	password=$(echo $login | cut -d'|' -f2)

	MYSQL=$(which mysql)

	$MYSQL -u $username -p$password -e "exit"
	login_state=$?

	if [ $login_state == 1 ]
	then
		zenity --error --width 300 --text "登录失败，请检查用户名和密码"
	fi
done

declare -i user_type=3
declare -i on_state=0
user_type=$($MYSQL -u "root" -p"F0cus.0n" -Bse "select type from homework.account where id ='$username'")

case $user_type in
	0) on_state=0 
	;;
	1) on_state=15
	;;
	2) on_state=30
	;;
	3)
		zenity --error --width 300 --text "账户类型错误"
		exit 1 
	;;
esac

temp_teacher_id=
temp_course_id=
present_course=
present_info=
present_hw=
present_stu=

declare -i hw_update=0

while [ 1 == 1 ]
do
	case $on_state in
		0)
			option=$(zenity --height=300 --width=280 --title="管理员" --list --text "请选择要进行的操作" --radiolist  --column "选择" \
			--column "功能" FALSE "查询/修改教师账号信息" FALSE "添加教师账号"\
			FALSE "查询/修改课程信息" FALSE "添加课程")
			
			if [ $? == 1 ]; then
				exit 0
			fi

			case $option in
				"查询/修改教师账号信息") on_state=1;;
				"添加教师账号") on_state=3;;
				"查询/修改课程信息") on_state=6;;
				"添加课程") on_state=7;;
			esac
		;;
		1)
			teacher_content=$($MYSQL -u$username -p$password homework -Bse "select * from teachers;")
			teacher_selected=$(zenity --list --title="教师账号列表" --ok-label="修改" --cancel-label="返回"\
			--text="可选中教师进行操作"\
			--height=600 --width=400 --column="工号" --column="姓名" $teacher_content)
			case $? in
				0) 
					if [ "$teacher_selected" != "" ]; then
						declare -i word;
						word=$($MYSQL -u$username -p$password homework -Bse "select name from teachers where ID = '$teacher_selected';" | wc -w)
						if [ $word != 0 ]; then
							temp_teacher_id=$teacher_selected
							on_state=2
						fi
					else
						zenity --info --width=250 --text "请选中一个教师" 2> >(grep -v GtkDialog >&2)
					fi
				;;
				1) on_state=0;;
			esac
		;;
		2)
			selected=$(zenity --height=300 --width=280 --title="修改教师账号信息" --list --text "请选择要进行的操作" --radiolist  --column "选择" \
			--column "功能" FALSE "修改教师姓名与账户密码" FALSE "绑定教师与课程" FALSE "解绑教师与课程" FALSE "删除教师")
			
			if [ $? == 1 ]; then
				on_state=1
				continue
			fi
			
			case $selected in
				"删除教师")
					on_state=4
				;;
				"修改教师姓名与账户密码")
					on_state=5
				;;
				"绑定教师与课程")
					on_state=11
				;;
				"解绑教师与课程")
					on_state=12
				;;
			esac
		;;
		3)
			teacher_info=$(zenity --forms --title="添加教师"\
			--text="请输入教师账号信息"\
			--text="姓名不得包含空格"\
			--add-entry="工号"\
			--add-entry="姓名"\
			--add-entry="密码" 2> >(grep -v GtkDialog >&2))
			if [ $? == 1 ]; then
				on_state=0
				continue
			fi
			teacher_id=$(echo $teacher_info | cut -d'|' -f1)
			teacher_name=$(echo $teacher_info | cut -d'|' -f2)
			teacher_passwd=$(echo $teacher_info | cut -d'|' -f3)
			if [ "$teacher_id" == "" ]; then
				zenity --info --width=250 --text "工号不能为空" 2> >(grep -v GtkDialog >&2)
				continue
			elif [ "$teacher_name" == "" ]; then
				zenity --info --width=250 --text "姓名不能为空" 2> >(grep -v GtkDialog >&2)
				continue
			elif [ "$teacher_passwd" == "" ]; then
				zenity --info --width=250 --text "密码不能为空" 2> >(grep -v GtkDialog >&2)
				continue
			fi
			$MYSQL -u$username -p$password homework <<EOF
create user '$teacher_id'@'localhost' identified by '$teacher_passwd';
grant all privileges on *.* to '$teacher_id'@'localhost' identified by '$teacher_passwd' with grant option;
grant CREATE USER on *.* to '$teacher_id'@'localhost' identified by '$teacher_passwd';
insert into teachers values('$teacher_id', '$teacher_name');
insert into account values('$teacher_id', 1);
EOF
			case $? in
				0) 
					zenity --info --width=150 --text "创建成功" 2> >(grep -v GtkDialog >&2)
					on_state=0
				;;
				1) zenity --info --width=150 --text "创建失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		4)
			teacher_id=$temp_teacher_id

			zenity --question --text "确定要删除该教师吗？"
			if [ $? == 1 ]; then
				on_state=2
				continue
			fi

			$MYSQL -u$username -p$password homework <<EOF
delete from teachers where ID = '$teacher_id';
delete from account where id = '$teacher_id';
delete from mysql.user where User = '$teacher_id';
drop user '$teacher_id'@'localhost';
flush privileges;
EOF
			
			case $? in
				0) 
					zenity --info --width=150 --text "删除成功" 2> >(grep -v GtkDialog >&2)
					on_state=1
				;;
				1) zenity --info --width=150 --text "删除失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		5)
			teacher_info=$(zenity --forms --width=300 --title="修改教师信息" --text="工号：$temp_teacher_id"\
			--text="姓名不得包含空格"\
			--add-entry="姓名"\
			--add-entry="密码" 2> >(grep -v GtkDialog >&2))
			if [ $? == 1 ]; then
				on_state=2
				continue
			fi

			teacher_name=$(echo $teacher_info | cut -d'|' -f1)
			teacher_passwd=$(echo $teacher_info | cut -d'|' -f2)
			if [ "$teacher_name" == "" ]; then
				zenity --info --width=250 --text "姓名不能为空" 2> >(grep -v GtkDialog >&2)
				continue
			elif [ "$teacher_passwd" == "" ]; then
				zenity --info --width=250 --text "密码不能为空" 2> >(grep -v GtkDialog >&2)
				continue
			fi
			$MYSQL -u$username -p$password homework <<EOF
update teachers set name = '$teacher_name' where ID = '$temp_teacher_id';
set password for '$temp_teacher_id'@'localhost' = password('$teacher_passwd');
flush privileges;
EOF
			case $? in
				0) 
					zenity --info --width=150 --text "修改成功" 2> >(grep -v GtkDialog >&2)
					on_state=1
				;;
				1) zenity --info --width=150 --text "修改失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		6)
			course_content=$($MYSQL -u$username -p$password homework -Bse "select * from course;")
			course_selected=$(zenity --list --title="课程列表" --height=600 --width=400 --column="课号" --column="课程名" $course_content)
			case $? in
				0) 
					on_state=0
					if [ "$course_selected" != "" ]; then
						declare -i word;
						word=$($MYSQL -u$username -p$password homework -Bse "select name from course where ID = '$course_selected';" | wc -w)
						if [ $word != 0 ]; then
							temp_course_id=$course_selected
							present_course=$course_selected
							on_state=8
						fi
					else
						zenity --info --width=250 --text "请选中一门课程" 2> >(grep -v GtkDialog >&2)
					fi
				;;
				1) on_state=0;;
			esac
		;;
		7)
			course_info=$(zenity --forms --title="添加课程"\
			--text="请输入课程信息"\
			--add-entry="课号"\
			--add-entry="课程名" 2> >(grep -v GtkDialog >&2))
			if [ $? == 1 ]; then
				on_state=0
				continue
			fi

			course_id=$(echo $course_info | cut -d'|' -f1)
			course_name=$(echo $course_info | cut -d'|' -f2)

			if [ "$course_id" == "" ]; then
				zenity --info --width=250 --text "课号不能为空" 2> >(grep -v GtkDialog >&2)
				continue
			elif [ "$course_name" == "" ]; then
				zenity --info --width=250 --text "课程名不能为空" 2> >(grep -v GtkDialog >&2)
				continue
			fi
			$MYSQL -u$username -p$password homework <<EOF
insert into course values('$course_id', '$course_name');
create table info_$course_id (timestamp char(10) primary key, issue_date date, title varchar(50), content_path varchar(65));
create table stu_$course_id (ID char(10) primary key, name varchar(35));
create table hw_$course_id (timestamp char(10) primary key, title varchar(50), type char(10), issue_date date, due_date date, content_path varchar(65));
EOF

			case $? in
				0) 
					zenity --info --width=150 --text "插入成功" 2> >(grep -v GtkDialog >&2)
				;;
				1) zenity --info --width=150 --text "插入失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		8)
			selected=$(zenity --height=300 --width=280 --title="修改课程信息" --list --text "请选择要进行的操作" --radiolist  --column "选择" \
			--column "功能" FALSE "修改课程名" FALSE "绑定教师与课程" FALSE "解绑教师与课程" FALSE "删除课程")
			
			if [ $? == 1 ]; then
				on_state=6
				continue
			fi
			
			case $selected in
				"修改课程名")
					on_state=9
				;;
				"删除课程")
					on_state=10
				;;
				"绑定教师与课程")
					on_state=13
				;;
				"解绑教师与课程")
					on_state=14
				;;
			esac
		;;
		9)
			course_name=$(zenity --forms --width=300 --title="修改课程名" --text="课号：$temp_course_id"\
			--add-entry="课程名" 2> >(grep -v GtkDialog >&2))
			if [ $? == 1 ]; then
				on_state=8
				continue
			fi
			if [ "$course_name" == "" ]; then
				zenity --info --width=250 --text "课程名不能为空" 2> >(grep -v GtkDialog >&2)
				continue
			fi
			$MYSQL -u$username -p$password homework <<EOF
update course set name = '$course_name' where ID = '$temp_course_id';
EOF
			case $? in
				0) 
					zenity --info --width=150 --text "修改成功" 2> >(grep -v GtkDialog >&2)
					on_state=6
				;;
				1) zenity --info --width=150 --text "修改失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		10)
			course_id=$temp_course_id

			zenity --question --text "确定要删除该课程吗？"

			if [ $? == 1 ]; then
				on_state=8
				continue
			fi

			hw_table_list=($($MYSQL -u$username -p$password homework -Bse "select TABLE_NAME from INFORMATION_SCHEMA.TABLES where TABLE_SCHEMA='homework' and TABLE_NAME like '${course_id}_hw_%';"))
			if [ ${#hw_table_list[@]} != 0 ]; then
				$MYSQL -u$username -p$password homework <<EOF
delete from course where ID = '$course_id';
drop table info_$course_id;
drop table stu_$course_id;
drop table hw_$course_id;
drop table ${hw_table_list[@]};
EOF
			else
				$MYSQL -u$username -p$password homework <<EOF
delete from course where ID = '$course_id';
drop table info_$course_id;
drop table stu_$course_id;
drop table hw_$course_id;
EOF
			fi
			
			case $? in
				0) 
					zenity --info --width=150 --text "删除成功" 2> >(grep -v GtkDialog >&2)
					on_state=6
				;;
				1) zenity --info --width=150 --text "删除失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		11)
			course_content=$($MYSQL -u$username -p$password homework -Bse "select * from course;")
			course_selected=$(zenity --list --title="课程列表" --text="请选择要绑定的课程"\
			--ok-label="绑定" --cancel-label="取消" --height=600 --width=400 --column="课号" --column="课程名" $course_content)

			if [ $? == 1 ]; then
				on_state=2
				continue
			fi

			if [ "$course_selected" == "" ]; then
				zenity --info --width=250 --text "请选择要绑定的课程" 2> >(grep -v GtkDialog >&2)
				continue
			fi
			if [ $($MYSQL -u$username -p$password homework -Bse "select * from teacher_course where course_ID = '$course_selected' and teacher_ID = '$temp_teacher_id';" | wc -w) == 0 ]; then
				$MYSQL -u$username -p$password homework <<EOF
insert into teacher_course values('$temp_teacher_id', '$course_selected');
EOF
				case $? in
					0) 
						zenity --info --width=150 --text "绑定成功" 2> >(grep -v GtkDialog >&2)
					;;
					1) zenity --info --width=150 --text "绑定失败" 2> >(grep -v GtkDialog >&2);;
				esac
			else
				zenity --info --width=350 --text "该教师和该课程已经被绑定过，无需绑定" 2> >(grep -v GtkDialog >&2)
			fi
		;;
		12)
			course_binded=$($MYSQL -u$username -p$password homework -Bse "select * from course where ID in (select course_ID from teacher_course where teacher_ID = '$temp_teacher_id');")
			course_selected=$(zenity --list --title="课程列表" --text="请选择要解绑的课程"\
			--ok-label="解绑" --cancel-label="取消" --height=600 --width=400 --column="课号" --column="课程名" $course_binded)

			if [ $? == 1 ]; then
				on_state=2
				continue
			fi

			if [ "$course_selected" == "" ]; then
				zenity --info --width=250 --text "请选择要解绑的课程" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			$MYSQL -u$username -p$password homework <<EOF
delete from teacher_course where teacher_ID = '$temp_teacher_id' and course_ID = '$course_selected';
EOF
			
			case $? in
				0) 
					zenity --info --width=150 --text "解绑成功" 2> >(grep -v GtkDialog >&2)
				;;
				1) zenity --info --width=150 --text "解绑失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		13)
			teacher_content=$($MYSQL -u$username -p$password homework -Bse "select * from teachers;")
			teacher_selected=$(zenity --list --title="教师账号列表" --ok-label="绑定" --cancel-label="取消"\
			--text="选择要绑定的教师"\
			--height=600 --width=400 --column="工号" --column="姓名" $teacher_content)
			case $? in
				0) 
					if [ "$teacher_selected" != "" ]; then
						declare -i word;
						word=$($MYSQL -u$username -p$password homework -Bse "select name from teachers where ID = '$teacher_selected';" | wc -w)
						if [ $word != 0 ]; then
							$MYSQL -u$username -p$password homework <<EOF
insert into teacher_course values('$teacher_selected', '$present_course');
EOF

							case $? in
								0) 
									zenity --info --width=150 --text "绑定成功" 2> >(grep -v GtkDialog >&2)
									on_state=8
								;;
								1) zenity --info --width=150 --text "绑定失败" 2> >(grep -v GtkDialog >&2);;
							esac
							
						fi
					else
						zenity --info --width=250 --text "请选中一个教师" 2> >(grep -v GtkDialog >&2)
					fi
				;;
				1) on_state=8;;
			esac
		;;
		14)
			teacher_content=$($MYSQL -u$username -p$password homework -Bse "select * from teachers where ID in (select teacher_ID from teacher_course where course_ID = '$present_course');")
			teacher_selected=$(zenity --list --title="教师账号列表" --ok-label="解绑" --cancel-label="取消"\
			--text="选择要解绑的教师"\
			--height=600 --width=400 --column="工号" --column="姓名" $teacher_content)

			if [ $? == 1 ]; then
				on_state=8
				continue
			fi

			if [ "$teacher_selected" == "" ]; then
				zenity --info --width=250 --text "请选择要解绑的课程" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			$MYSQL -u$username -p$password homework <<EOF
delete from teacher_course where teacher_ID = '$teacher_selected' and course_ID = '$present_course';
EOF
			
			case $? in
				0) 
					zenity --info --width=150 --text "解绑成功" 2> >(grep -v GtkDialog >&2)
					on_state=8
				;;
				1) zenity --info --width=150 --text "解绑失败" 2> >(grep -v GtkDialog >&2);;
			esac

		;;
		15)
			course_id=($($MYSQL -u$username -p$password homework -Bse "select ID from course where ID in (select course_id from teacher_course where \
				teacher_id = '$username');"))
			course_name=($($MYSQL -u$username -p$password homework -Bse "select name from course where ID in (select course_id from teacher_course where \
				teacher_id = '$username');"))
			course_list=()
			for(( i=0; i<${#course_id[@]}; i++ ))
			do
				course_list+=(FALSE "${course_id[$i]}" "${course_name[$i]}")
			done

			option=$(zenity --height=500 --width=400 --title="教师" --list --text "请选择要管理的课程" --radiolist  --column "选择" \
			--column "课号" --column "课程名" "${course_list[@]}")

			if [ $? == 1 ]; then
				exit 0
			fi

			if [ "$option" == "" ]; then
				zenity --info --width=150 --text "请选择要管理的课程" 2> >(grep -v GtkDialog >&2)
				continue
			else
				present_course=$option
				on_state=16
			fi
		;;
		16)
			option=$(zenity --height=400 --width=280 --title="教师" --list --text "当前课程：$present_course" --radiolist  --column "选择" \
			--column "功能" FALSE 创建学生账号 FALSE 查询学生账号 FALSE 导入学生账号 FALSE 删除课程学生 FALSE 新建课程信息 FALSE 管理课程信息 FALSE 新建作业/实验  FALSE 管理作业/实验)

			if [ $? == 1 ]; then
				on_state=15
				continue
			fi

			case $option in
				"新建课程信息")
					on_state=17
					continue
				;;
				"管理课程信息")
					on_state=18
					continue
				;;
				"查询学生账号")
					on_state=22
					continue
				;;
				"导入学生账号")
					on_state=220
					continue
				;;
				"创建学生账号")
					on_state=23
					continue
				;;
				"删除课程学生")
					on_state=230
					continue
				;;
				"新建作业/实验")
					on_state=24
					continue
				;;
				"管理作业/实验")
					on_state=25
					continue
				;;
			esac
		;;
		17)
			info=$(yad --center --width=400 --height=500 -margin=15 \
			--title="新建课程信息" --text="请输入课程信息" \
			--form --date-format="%y-%m-%d" \
			--field="标题" \
			--field="日期":DT \
			--field="内容":TXT)

			if [ $? == 1 ]; then
				on_state=16
				continue
			fi

			info_content=${info// /^^^}
			info_content=${info_content//|/ }
			info_con=($info_content)

			if [[ ${#info_con[@]} < 3 ]]; then
				zenity --info --width=150 --text "不允许有空栏" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			info_title="${info_con[0]//^^^/ }"
			info_date="${info_con[1]//^^^/ }"
			info_content="${info_con[2]//^^^/ }"
			timestamp=$(date +%s)

			if ! [ -d $client_path/info ]; then
				mkdir $client_path/info
			fi

			if ! [ -d $client_path/info/info_$present_course ]; then
				mkdir $client_path/info/info_$present_course
			fi

			touch "$client_path/info/info_$present_course/$timestamp"
			printf "$info_content" > "$client_path/info/info_$present_course/$timestamp"
			content_path="$client_path/info/info_$present_course/$timestamp"

			$MYSQL -u$username -p$password homework <<EOF
insert into info_$present_course values('$timestamp', '$info_date', '$info_title', '$content_path');
EOF
			case $? in
				0) zenity --info --width=150 --text "创建成功" 2> >(grep -v GtkDialog >&2);;
				1) zenity --info --width=150 --text "创建失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		18)
			title_all=$($MYSQL -u$username -p$password homework -Bse "select title from info_$present_course;")
			title_all=${title_all// /^^^}
			title=($title_all)

			date=($($MYSQL -u$username -p$password homework -Bse "select issue_date from info_$present_course;"))
			timestamp=($($MYSQL -u$username -p$password homework -Bse "select timestamp from info_$present_course;"))
			info_list=()
			for ((i=0; i<${#title[@]}; i++)); do
				info_list+=("${timestamp[$i]}" "${date[$i]}" "${title[$i]//^^^/ }")
			done

			info_selected=$(zenity --list --title="公告列表" --text="请选择要处理的课程信息/公告"\
			--height=600 --width=400 --column="编号" --column="日期" --column="标题" "${info_list[@]}")

			if [ $? == 1 ]; then
				on_state=16
				continue
			fi

			if [ "$info_selected" == "" ]; then
				zenity --info --width=150 --text "请选择要处理的课程信息" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			present_info=$info_selected
			on_state=19
		;;
		19)
			selected=$(zenity --height=300 --width=280 --title="修改公告" --list --text "请选择要进行的操作" --radiolist  --column "选择" \
			--column "功能" FALSE "编辑公告内容" FALSE "删除公告")
			
			if [ $? == 1 ]; then
				on_state=18
				continue
			fi
			
			case $selected in
				"编辑公告内容")
					on_state=20
				;;
				"删除公告")
					on_state=21
				;;
			esac
		;;
		20)
			pre_date="$($MYSQL -u$username -p$password homework -Bse "select issue_date from info_$present_course where timestamp='$present_info';")"
			pre_title="$($MYSQL -u$username -p$password homework -Bse "select title from info_$present_course where timestamp='$present_info';")"
			pre_path="$($MYSQL -u$username -p$password homework -Bse "select content_path from info_$present_course where timestamp='$present_info';")"
			pre_content="$(cat "$pre_path")"
			
			info=$(yad --center --width=400 --height=500 -margin=15 \
			--title="修改课程信息" --text="请输入课程信息" \
			--form --date-format="%y-%m-%d" \
			--field="标题" \
			--field="日期":DT \
			--field="内容":TXT \
			"$pre_title" "$pre_date" "$pre_content")

			if [ $? == 1 ]; then
				on_state=19
				continue
			fi

			info_content=${info// /^^^}
			info_content=${info_content//|/ }
			info_con=($info_content)

			if [[ ${#info_con[@]} < 3 ]]; then
				zenity --info --width=150 --text "不允许有空栏" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			info_title="${info_con[0]//^^^/ }"
			info_date="${info_con[1]//^^^/ }"
			info_content="${info_con[2]//^^^/ }"
			timestamp=$present_info

			rm -f "$client_path/info/info_$present_course/$timestamp"
			touch "$client_path/info/info_$present_course/$timestamp"
			printf "$info_content" > "$client_path/info/info_$present_course/$timestamp"
			content_path="$client_path/info/info_$present_course/$timestamp"

			$MYSQL -u$username -p$password homework <<EOF
delete from info_$present_course where timestamp='$timestamp';
insert into info_$present_course values('$timestamp', '$info_date', '$info_title', '$content_path');
EOF
			case $? in
				0) zenity --info --width=150 --text "修改成功" 2> >(grep -v GtkDialog >&2);;
				1) zenity --info --width=150 --text "修改失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		21)
			zenity --question --title "删除公告" --text "确定要删除该公告吗？"

			if [ $? == 1 ]; then
				on_state=18
				continue
			fi

			info_file="$($MYSQL -u$username -p$password homework -Bse "select content_path from info_$present_course where timestamp='$present_info';")"

			rm "$info_file"
			$MYSQL -u$username -p$password homework <<EOF
delete from info_$present_course where timestamp = '$present_info';
EOF
			
			case $? in
				0) 
					zenity --info --width=150 --text "删除成功" 2> >(grep -v GtkDialog >&2)
					on_state=18
				;;
				1) zenity --info --width=150 --text "删除失败" 2> >(grep -v GtkDialog >&2);;
			esac
			
		;;
		22)
			id=$(zenity --entry --text "输入待查询的学生账号");

			stu=($($MYSQL -u$username -p$password homework -Bse "select * from students where ID='$id';"))
			stu_list=()

			if [ ${#stu[@]} != 0 ]; then
				stu_list=(FALSE "${stu[@]}")
			fi

			student_selected=$(zenity --height=300 --width=280 --title="学生查询" --list --text "可选择学生加入课程" --checklist --ok-label="添加" --cancel-label="返回" --column "选择" \
			--column "学号" --column "姓名" ${stu_list[@]})

			if [ $? == 1 ]; then
				on_state=16
				continue
			fi

			if [ "$student_selected" = "" ]; then
				zenity --info --width=150 --text "请选择至少一个学生" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			$MYSQL -u$username -p$password homework <<EOF
insert into stu_$present_course select * from students where ID = '$student_selected';
EOF
			case $? in
				0) 
					zenity --info --width=150 --text "加入成功" 2> >(grep -v GtkDialog >&2)
					on_state=16
				;;
				1) zenity --info --width=150 --text "加入失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		220)
			stu_id=($($MYSQL -u$username -p$password homework -Bse "select ID from students where ID not in (select student_ID from stu_course where course_ID='$present_course');"))
			stu_name=($($MYSQL -u$username -p$password homework -Bse "select name from students where ID not in (select student_ID from stu_course where course_ID='$present_course');"))
			stu_list=()

			for ((i=0; i<${#stu[@]}; i++)); do
				stu_list+=(FALSE ${stu_id[$i]} ${stu_name[$i]})
			done

			student_selected=$(zenity --height=300 --width=280 --title="学生查询" --list --text "可选择学生加入课程" --checklist --ok-label="添加" --cancel-label="返回" --column "选择" \
			--column "学号" --column "姓名" ${stu_list[@]})

			echo ${student_selected}
		;;
		23)
			stu_info=$(zenity --forms --title="创建学生账号"\
			--text="请输入学生账号信息"\
			--add-entry="学号"\
			--add-entry="姓名"\
			--add-entry="密码" 2> >(grep -v GtkDialog >&2))
			if [ $? == 1 ]; then
				on_state=16
				continue
			fi
			stu_id=$(echo $stu_info | cut -d'|' -f1)
			stu_name="$(echo $stu_info | cut -d'|' -f2)"
			stu_passwd=$(echo $stu_info | cut -d'|' -f3)
			if [ "$stu_id" == "" ]; then
				zenity --info --width=250 --text "学号不能为空" 2> >(grep -v GtkDialog >&2)
				continue
			elif [ "$stu_name" == "" ]; then
				zenity --info --width=250 --text "姓名不能为空" 2> >(grep -v GtkDialog >&2)
				continue
			elif [ "$stu_passwd" == "" ]; then
				zenity --info --width=250 --text "密码不能为空" 2> >(grep -v GtkDialog >&2)
				continue
			fi
			$MYSQL -u$username -p$password homework <<EOF
create user '$stu_id'@'localhost' identified by '$stu_passwd';
grant all privileges on homework.* to '$stu_id'@'localhost' identified by '$stu_passwd';
insert into students values('$stu_id', '$stu_name');
insert into account values('$stu_id', 2);
insert into stu_$present_course values('$stu_id', '$stu_name');
insert into stu_course values('$stu_id', '$present_course');
EOF
			case $? in
				0) 
					zenity --info --width=150 --text "创建成功" 2> >(grep -v GtkDialog >&2)
					on_state=16
				;;
				1) zenity --info --width=150 --text "创建失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		230)
			stu_id=($($MYSQL -u$username -p$password homework -Bse "select ID from students where ID in (select student_ID from stu_course where course_ID='$present_course');"))
			stu_name=$($MYSQL -u$username -p$password homework -Bse "select name from students where ID in (select student_ID from stu_course where course_ID='$present_course');")
			stu_name=${stu_name// /^^^}
			name_list=($stu_name)
			stu_list=()

			for ((i=0; i<${#stu_id[@]}; i++)); do
				stu_list+=(FALSE "${stu_id[$i]}" "${name_list[$i]//^^^/ }")
			done

			student_selected=$(zenity --height=500 --width=400 --title="学生查询" --list --text "可从课程中删除学生" --checklist --ok-label="删除" --cancel-label="返回" --column "选择" \
			--column "学号" --column "姓名" ${stu_list[@]})

			if [ $? == 1 ]; then
				on_state=16
				continue
			fi

			student_selected=${student_selected// /^^^}
			student_selected=${student_selected//|/ }
			student_selected_list=($student_selected)

			for ((i=0; i<${#student_selected_list[@]}; i++)); do
				$MYSQL -u$username -p$password homework <<EOF
delete from stu_course where student_ID = '${student_selected_list[$i]}' and course_ID = '$present_course';
delete from stu_$present_course where ID = '${student_selected_list[$i]}';
EOF
			done

			hw_list=($($MYSQL -u$username -p$password homework -Bse "select timestamp from hw_$present_course;"))

			for ((i=0; i<${#hw_list[@]}; i++)); do
				$MYSQL -u$username -p$password homework <<EOF
delete from ${present_course}_hw_${hw_list[$i]} where stu_ID = '${student_selected_list[$i]}';
EOF
			done

			case $? in
				0) 
					zenity --info --width=150 --text "删除成功" 2> >(grep -v GtkDialog >&2)
					on_state=16
				;;
				1) zenity --info --width=150 --text "删除失败" 2> >(grep -v GtkDialog >&2);;
			esac
			
		;;
		24)
			hw=$(yad --center --width=400 --height=500 -margin=15 \
			--title="新建作业/实验" --text="请输入作业/实验信息" \
			--form --date-format="%y-%m-%d" \
			--field="标题" \
			--field="类型":CB \
			--field="发布日期":DT \
			--field="截止日期":DT \
			--field="内容":TXT \
			"" "作业!实验" "" "" "" )

			if [ $? == 1 ]; then
				on_state=16
				continue
			fi

			hw_content=${hw// /^^^}
			hw_content=${hw_content//|/ }
			hw_con=($hw_content)

			if [[ ${#hw_con[@]} < 5 ]]; then
				zenity --info --width=150 --text "不允许有空栏" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			hw_title="${hw_con[0]//^^^/ }"
			hw_type="${hw_con[1]//^^^/ }"
			hw_issue_date="${hw_con[2]//^^^/ }"
			hw_due_date="${hw_con[3]//^^^/ }"
			hw_content="${hw_con[4]//^^^/ }"
			timestamp=$(date +%s)

			if ! [ -d $client_path/hw ]; then
				mkdir $client_path/hw
			fi

			if ! [ -d $client_path/hw/hw_$present_course ]; then
				mkdir $client_path/hw/hw_$present_course
			fi

			touch "$client_path/hw/hw_$present_course/$timestamp"
			mkdir "$client_path/hw/hw_$present_course/stu_$timestamp"
			printf "$hw_content" > "$client_path/hw/hw_$present_course/$timestamp"
			content_path="$client_path/hw/hw_$present_course/$timestamp"

			$MYSQL -u$username -p$password homework <<EOF
insert into hw_$present_course values('$timestamp', '$hw_title', '$hw_type',  '$hw_issue_date', '$hw_due_date', '$content_path');
create table ${present_course}_hw_$timestamp(stu_id varchar(35), file_path varchar(120), point numeric(3));
EOF
			case $? in
				0) 
					zenity --info --width=150 --tex  "创建成功" 2> >(grep -v GtkDialog >&2)
					on_state=16
				;;
				1) zenity --info --width=150 --text "创建失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		25)
			title_all=$($MYSQL -u$username -p$password homework -Bse "select title from hw_$present_course;")
			title_all=${title_all// /^^^}
			title=($title_all)

			timestamp=($($MYSQL -u$username -p$password homework -Bse "select timestamp from hw_$present_course;"))
			due_date=($($MYSQL -u$username -p$password homework -Bse "select due_date from hw_$present_course;"))
			issue_date=($($MYSQL -u$username -p$password homework -Bse "select issue_date from hw_$present_course;"))
			hw_list=()
			for ((i=0; i<${#title[@]}; i++)); do
				hw_list+=("${timestamp[$i]}" "${title[$i]//^^^/ }" "${issue_date[$i]}" "${due_date[$i]}")
			done

			hw_selected=$(zenity --list --title="作业/实验列表" --text="请选择要处理的课程作业/实验"\
			--height=600 --width=400 --column="编号" --column="标题" --column="发布日期" --column="截止日期" "${hw_list[@]}")

			if [ $? == 1 ]; then
				on_state=16
				continue
			fi

			if [ "$hw_selected" == "" ]; then
				zenity --info --width=150 --text "请选择要处理的作业/实验" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			present_hw=$hw_selected
			on_state=26
		;;
		26)
			selected=$(zenity --height=300 --width=280 --title="处理作业/实验" --list --text "请选择要进行的操作" --radiolist  --column "选择" \
			--column "功能" FALSE "批阅作业" FALSE "修改要求" FALSE "删除作业")
			
			if [ $? == 1 ]; then
				on_state=25
				continue
			fi
			
			case $selected in
				"批阅作业")
					on_state=27
				;;
				"修改要求")
					on_state=28
				;;
				"删除作业")
					on_state=29
				;;
			esac
		;;
		27)
			stu_id=$($MYSQL -u$username -p$password homework -Bse "select stu_id from ${present_course}_hw_$present_hw;")
			path_all=$($MYSQL -u$username -p$password homework -Bse "select file_path from ${present_course}_hw_$present_hw;")
			path_all=${path_all// /^^^}
			path=($path_all)

			stu_hw_list=()
			for ((i=0; i<${#stu_id[@]}; i++)); do
				stu_hw_list+=("${stu_id[$i]}" "${path[$i]//^^^/ }")
			done

			not_submit=($($MYSQL -u$username -p$password homework -Bse "select ID from stu_$present_course where ID not in (select stu_id from ${present_course}_hw_$present_hw);"))
			n_submit=()
			for ((i=0; i<${#not_submit[@]}; i++)); do
				n_submit+=("${not_submit[$i]}" "未提交")
			done

			id_selected=$(zenity --list --title="学生列表" --text="请选择要批阅的学生作业"\
			--ok-label="批阅" --cancel-label="取消" --height=600 --width=400 --column="学生" --column="作业路径" "${stu_hw_list[@]}" "${n_submit[@]}")

			if [ $? == 1 ]; then
				on_state=26
				continue
			fi

			if [ $($MYSQL -u$username -p$password homework -Bse "select stu_id from ${present_course}_hw_$timestamp where stu_id = '$id_selected';" | wc -w) == 0 ]; then
				zenity --info --width=150 --text "该学生尚未提交作业" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			present_stu="$id_selected"
			on_state=270
	
		;;
		270)
			path="$($MYSQL -u$username -p$password homework -Bse "select file_path from ${present_course}_hw_$present_hw where stu_id = '$present_stu';" )"
			xdg-open "$path"

			score=$(zenity --entry --text="请输入分数")

			if [ $? == 1 ]; then
				on_state=27
			fi

			$MYSQL -u$username -p$password homework <<EOF
update ${present_course}_hw_$timestamp set point=$score where stu_id = '$present_stu' ;
EOF
			case $? in
				0) 
					zenity --info --width=150 --text  "批改成功" 2> >(grep -v GtkDialog >&2)
					on_state=27
				;;
				1) zenity --info --width=150 --text "批改失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		28)
			pre_title="$($MYSQL -u$username -p$password homework -Bse "select title from hw_$present_course where timestamp='$present_hw';")"
			pre_type="$($MYSQL -u$username -p$password homework -Bse "select type from hw_$present_course where timestamp='$present_hw';")"
			pre_issue="$($MYSQL -u$username -p$password homework -Bse "select issue_date from hw_$present_course where timestamp='$present_hw';")"
			pre_due="$($MYSQL -u$username -p$password homework -Bse "select due_date from hw_$present_course where timestamp='$present_hw';")"
			pre_path="$($MYSQL -u$username -p$password homework -Bse "select content_path from hw_$present_course where timestamp='$present_hw';")"
			pre_content="$(cat "$pre_path")"

			if [ "$pre_type" == "作业" ]; then
				pre_type="作业!实验"
			else
				pre_type="实验!作业"
			fi

			hw=$(yad --center --width=400 --height=500 -margin=15 \
			--title="新建作业/实验" --text="请输入作业/实验信息" \
			--form --date-format="%y-%m-%d" \
			--field="标题" \
			--field="类型":CB \
			--field="发布日期":DT \
			--field="截止日期":DT \
			--field="内容":TXT \
			"$pre_title" "$pre_type" "$pre_issue" "$pre_due" "$pre_content" )

			if [ $? == 1 ]; then
				on_state=26
				continue
			fi

			hw_content=${hw// /^^^}
			hw_content=${hw_content//|/ }
			hw_con=($hw_content)

			if [[ ${#hw_con[@]} < 5 ]]; then
				zenity --info --width=150 --text "不允许有空栏" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			hw_title="${hw_con[0]//^^^/ }"
			hw_type="${hw_con[1]//^^^/ }"
			hw_issue_date="${hw_con[2]//^^^/ }"
			hw_due_date="${hw_con[3]//^^^/ }"
			hw_content="${hw_con[4]//^^^/ }"
			timestamp=$present_hw

			rm -f "$client_path/hw/hw_$present_course/$timestamp"
			touch "$client_path/hw/hw_$present_course/$timestamp"
			printf "$hw_content" > "$client_path/hw/hw_$present_course/$timestamp"
			content_path="$client_path/hw/hw_$present_course/$timestamp"

			$MYSQL -u$username -p$password homework <<EOF
delete from hw_$present_course where timestamp = '$timestamp';
insert into hw_$present_course values('$timestamp', '$hw_title', '$hw_type',  '$hw_issue_date', '$hw_due_date', '$content_path');
EOF
			case $? in
				0) 
					zenity --info --width=150 --tex  "修改成功" 2> >(grep -v GtkDialog >&2)
					on_state=26
				;;
				1) zenity --info --width=150 --text "修改失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		29)
			zenity --question --text "确定要删除该作业/实验吗？"
			if [ $? == 1 ]; then
				on_state=26
				continue
			fi

			$MYSQL -u$username -p$password homework <<EOF
delete from hw_${present_course} where timestamp = '$present_hw';
drop table ${present_course}_hw_$present_hw;
EOF
			case $? in
				0) 
					zenity --info --width=150 --tex  "删除成功" 2> >(grep -v GtkDialog >&2)
					on_state=26
				;;
				1) zenity --info --width=150 --text "删除失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		30)
			course_id=($($MYSQL -u$username -p$password homework -Bse "select ID from course where ID in (select course_id from stu_course where \
				student_id = '$username');"))
			course_name=($($MYSQL -u$username -p$password homework -Bse "select name from course where ID in (select course_id from stu_course where \
				student_id = '$username');"))
			course_list=()
			for(( i=0; i<${#course_id[@]}; i++ ))
			do
				course_list+=(FALSE "${course_id[$i]}" "${course_name[$i]}")
			done

			option=$(zenity --height=500 --width=400 --title="学生" --list --text "请选择要操作的课程" --radiolist  --column "选择" \
			--column "课号" --column "课程名" "${course_list[@]}")

			if [ $? == 1 ]; then
				exit 0
			fi

			if [ "$option" == "" ]; then
				zenity --info --width=150 --text "请选择要操作的课程" 2> >(grep -v GtkDialog >&2)
				continue
			else
				present_course=$option
				on_state=31
			fi
		;;
		31)
			option=$(zenity --height=400 --width=280 --title="学生" --list --text "当前课程：$present_course" --radiolist  --column "选择" \
			--column "功能" FALSE 查看课程公告 FALSE 查看作业与实验)

			if [ $? == 1 ]; then
				on_state=30
				continue
			fi

			case $option in
				"查看课程公告")
					on_state=32
				;;
				"查看作业与实验")
					on_state=34
				;;
			esac
		;;
		32)
			title_all=$($MYSQL -u$username -p$password homework -Bse "select title from info_$present_course;")
			title_all=${title_all// /^^^}
			title=($title_all)

			date=($($MYSQL -u$username -p$password homework -Bse "select issue_date from info_$present_course;"))
			timestamp=($($MYSQL -u$username -p$password homework -Bse "select timestamp from info_$present_course;"))
			info_list=()
			for ((i=0; i<${#title[@]}; i++)); do
				info_list+=("${timestamp[$i]}" "${date[$i]}" "${title[$i]//^^^/ }")
			done

			info_selected=$(zenity --list --title="公告列表" --text="请选择要处理的课程信息/公告"\
			--height=600 --width=400 --column="编号" --column="日期" --column="标题" "${info_list[@]}")

			if [ $? == 1 ]; then
				on_state=31
				continue
			fi

			if [ "$info_selected" == "" ]; then
				zenity --info --width=150 --text "请选择要处理的课程信息" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			present_info=$info_selected
			on_state=33
		;;
		33)
			file="$($MYSQL -u$username -p$password homework -Bse "select content_path from info_$present_course where timestamp = '$present_info'")"
			title="$($MYSQL -u$username -p$password homework -Bse "select title from info_$present_course where timestamp = '$present_info'")"
			zenity --text-info --filename="$file" --title="$title"

			on_state=32
		;;
		34)
			title_all=$($MYSQL -u$username -p$password homework -Bse "select title from hw_$present_course;")
			title_all=${title_all// /^^^}
			title=($title_all)

			i_date=($($MYSQL -u$username -p$password homework -Bse "select issue_date from hw_$present_course;"))
			d_date=($($MYSQL -u$username -p$password homework -Bse "select due_date from hw_$present_course;"))
			timestamp=($($MYSQL -u$username -p$password homework -Bse "select timestamp from hw_$present_course;"))
			hw_list=()
			state=
			for ((i=0; i<${#title[@]}; i++)); do
				hw_list+=("${timestamp[$i]}" "${title[$i]//^^^/ }" "${i_date[$i]}" "${d_date[$i]}")
				hw_state=$($MYSQL -u$username -p$password homework -Bse "select stu_id from ${present_course}_hw_$timestamp where stu_id = '$username';" | wc -w)
				if [ $hw_state == 0 ]; then
					state="未提交"
				else
					if [ $($MYSQL -u$username -p$password homework -Bse "select point from ${present_course}_hw_$timestamp where stu_id = '$username';") != NULL ]; then
						state="$($MYSQL -u$username -p$password homework -Bse "select point from ${present_course}_hw_$timestamp where stu_id = '$username';")"
					else
						state="未评分"
					fi
				fi
				hw_list+=("$state")
			done

			hw_selected=$(zenity --list --title="作业与实验列表" --text="请选择要处理的作业或实验/公告"\
			--height=600 --width=600 --column="编号" --column="标题" --column="发布日期" --column="截止日期" --column="状态/得分" "${hw_list[@]}")

			if [ $? == 1 ]; then
				on_state=31
				continue
			fi

			if [ "$hw_selected" == "" ]; then
				zenity --info --width=150 --text "请选择要处理的课程或实验" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			present_hw=$hw_selected
			on_state=35
		;;
		35)
			title="$($MYSQL -u$username -p$password homework -Bse "select title from hw_$present_course where timestamp='$present_hw';")"
			hw_path="$($MYSQL -u$username -p$password homework -Bse "select content_path from hw_$present_course where timestamp='$present_hw';")"
			type="$($MYSQL -u$username -p$password homework -Bse "select type from hw_$present_course where timestamp='$present_hw';")"
			issue_date="$($MYSQL -u$username -p$password homework -Bse "select issue_date from hw_$present_course where timestamp='$present_hw';")"
			due_date="$($MYSQL -u$username -p$password homework -Bse "select due_date from hw_$present_course where timestamp='$present_hw';")"

			yad --center --width=400 --height=500 -margin=15 \
			--title="$title" --text="\n  类型：${type}\n\n  发布日期：${issue_date}\n\n  截止日期：${due_date}\n" \
			--text-info \
			--filename="$hw_path" \
			--button="返回":1\
			--button="提交作业":0

			case $? in
				0) on_state=36;;
				1) on_state=34;;
			esac
		;;
		36)
			selected=$(zenity --height=300 --width=280 --title="提交作业" --list --text "请选择作业提交方式" --radiolist  --column "选择" \
			--column "方式" FALSE "选取本地文件" FALSE "新建文件")
			
			if [ $? == 1 ]; then
				on_state=35
				continue
			fi
			
			case $selected in
				"选取本地文件")
					on_state=37
				;;
				"新建文件")
					on_state=38
				;;
			esac
		;;
		37)
			file="$(zenity --height=600 --width=800 --file-selection --title="选择作业文件" --multiple --separator="^^^" 2> >(grep -v GtkDialog >&2))" 

			if [ $? == 1 ]; then
				on_state=36
				continue
			fi

			file=${file// /!!!}
			file=${file//^^^/ }
			file_list=($file)

			if [ -d $client_path/hw/hw_$present_course/stu_$present_hw/$username ]; then
				zenity --question --text "是否保留上次提交的作业？" --ok-label="保留" --cancel-label="丢弃"
				if [ $? == 1 ]; then
					rm -r $client_path/hw/hw_$present_course/stu_$present_hw/$username
					mkdir $client_path/hw/hw_$present_course/stu_$present_hw/$username
					for(( i=0; i<${#file_list[@]}; i++ ))
					do
						filename=${file_list[i]//!!!/ }
						cp $filename $client_path/hw/hw_$present_course/stu_$present_hw/$username
					done
				else
					for(( i=0; i<${#file_list[@]}; i++ ))
					do
						filename=${file_list[i]//!!!/ }
						realname=${filename##*/}
						if [ -e "$client_path/hw/hw_$present_course/stu_$present_hw/$username/$realname" ]; then
							declare -i num=0
							while [ -e "$client_path/hw/hw_$present_course/stu_$present_hw/$username/${realname}_$num" ]; do
								num=$num+1
							done
							realname=${realname}_$num
						fi
						cp $filename $client_path/hw/hw_$present_course/stu_$present_hw/$username/$realname
					done
				fi
			else
				mkdir $client_path/hw/hw_$present_course/stu_$present_hw/$username
				for(( i=0; i<${#file_list[@]}; i++ ))
				do
					filename=${file_list[i]//!!!/ }
					cp $filename $client_path/hw/hw_$present_course/stu_$present_hw/$username
				done
			fi

			$MYSQL -u$username -p$password homework <<EOF
delete from ${present_course}_hw_$timestamp where stu_id = '$username';
insert into ${present_course}_hw_$timestamp values('$username', '$client_path/hw/hw_$present_course/stu_$present_hw/$username', NULL);
EOF
			case $? in
				0) 
					zenity --info --width=150 --text "提交成功" 2> >(grep -v GtkDialog >&2)
					on_state=35
				;;
				1) zenity --info --width=150 --text "提交失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		38)
			newhw="$(yad --center --width=400 --height=500 -margin=15 \
			--title="新建作业/实验" --text="请输入作业内容" \
			--form --date-format="%y-%m-%d" \
			--field="标题" \
			--field="内容":TXT )"

			if [ $? == 1 ]; then
				on_state=36
				continue
			fi

			if [ -d $client_path/hw/hw_$present_course/stu_$present_hw/$username ]; then
				zenity --question --text "是否保留上次提交的作业？" --ok-label="保留" --cancel-label="丢弃"
				if [ $? == 1 ]; then
					rm -r $client_path/hw/hw_$present_course/stu_$present_hw/$username
					mkdir $client_path/hw/hw_$present_course/stu_$present_hw/$username
				fi
			else
				mkdir $client_path/hw/hw_$present_course/stu_$present_hw/$username
			fi

			newhw="${newhw// /^^^}"
			newhw="${newhw//|/ }"
			newhw_item=($newhw)

			if [[ ${#newhw_item[@]} < 2 ]]; then
				zenity --info --width=150 --text "不允许有空栏" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			hw_title="${newhw_item[0]//^^^/ }"
			hw_content="${newhw_item[1]//^^^/ }"

			if [ -e "$client_path/hw/hw_$present_course/stu_$present_hw/$username/$hw_title" ]; then
				declare -i num=0
				while [ -e "$client_path/hw/hw_$present_course/stu_$present_hw/$username/${hw_title}_$num" ]; do
					num=$num+1
				done
				hw_title=${hw_title}_$num
			fi

			touch $client_path/hw/hw_$present_course/stu_$present_hw/$username/$hw_title
			printf "$hw_content" > "$client_path/hw/hw_$present_course/stu_$present_hw/$username/$hw_title"

			$MYSQL -u$username -p$password homework <<EOF
delete from ${present_course}_hw_$timestamp where stu_id = '$username';
insert into ${present_course}_hw_$timestamp values('$username', '$client_path/hw/hw_$present_course/stu_$present_hw/$username', NULL);
EOF

			case $? in
				0) 
					zenity --info --width=150 --text "提交成功" 2> >(grep -v GtkDialog >&2)
					on_state=35
				;;
				1) zenity --info --width=150 --text "提交失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
	esac
done