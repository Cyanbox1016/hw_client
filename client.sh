#! /bin/bash

let login_state=1

while [ $login_state == 1 ]
do
	login=$(zenity  --username --password --title "登录到作业系统")
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
	1) on_state=10
	;;
	2) on_state=20
	;;
	3)
		zenity --error --width 300 --text "账户类型错误"
		exit 1 
	;;
esac

temp_teacher_id=
temp_course_id=

while [ 1 == 1 ]
do
	case $on_state in
		0)
			option=$(zenity --height=300 --width=280 --title="管理员" --list --text "请选择要进行的操作" --radiolist  --column "选择" \
			--column "功能" FALSE "查看教师账号" FALSE "添加教师账号" FALSE "删除教师账号"\
			FALSE "查看课程" FALSE "添加课程" FALSE "删除课程")
			
			if [ $? == 1 ]; then
				exit 0
			fi

			case $option in
				"查看教师账号") on_state=1;;
				"添加教师账号") on_state=2;;
				"删除教师账号") on_state=3;;
				"查看课程") on_state=5;;
				"添加课程") on_state=6;;
				"删除课程") on_state=7;; 
			esac
		;;
		1)
			teacher_content=$($MYSQL -u$username -p$password homework -Bse "select * from teachers;")
			teacher_selected=$(zenity --list --title="教师账号列表" --ok-label="修改" --cancel-label="返回" --extra-button --extra-label="绑定课程" --height=600 --width=400 --column="工号" --column="姓名" $teacher_content)
			echo $?
			case $? in
				0) 
					on_state=0
					if [ "$teacher_selected" != "" ]; then
						declare -i word;
						word=$($MYSQL -u$username -p$password homework -Bse "select name from teachers where ID = '$teacher_selected';" | wc -w)
						if [ $word != 0 ]; then
							temp_teacher_id=$teacher_selected
							on_state=4
						fi
					fi
				;;
				1) on_state=0;;
			esac
		;;
		2)
			teacher_info=$(zenity --forms --title="添加教师"\
			--text="请输入教师账号信息"\
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
insert into teachers values('$teacher_id', '$teacher_name');
insert into account values('$teacher_id', 1);
create user '$teacher_id'@'localhost' identified by '$teacher_passwd';
EOF
			case $? in
				0) 
					zenity --info --width=150 --text "插入成功" 2> >(grep -v GtkDialog >&2)
					on_state=0
				;;
				1) zenity --info --width=150 --text "插入失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		3)
			teacher_id=$(zenity --forms --title="删除教师"\
			--text="请输入教师工号"\
			--add-entry="工号" 2> >(grep -v GtkDialog >&2))

			if [ $? == 1 ]; then
				on_state=0
				continue
			fi

			$MYSQL -u$username -p$password homework <<EOF
delete from teachers where ID = '$teacher_id';
delete from account where id = '$teacher_id';
delete from mysql.user where User = '$teacher_id';
flush privileges;
EOF
			
			case $? in
				0) 
					zenity --info --width=150 --text "删除成功" 2> >(grep -v GtkDialog >&2)
					on_state=0
				;;
				1) zenity --info --width=150 --text "删除失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		4)
			teacher_info=$(zenity --forms --width=300 --title="修改教师信息" --text="工号：$temp_teacher_id"\
			--add-entry="姓名"\
			--add-entry="密码" 2> >(grep -v GtkDialog >&2))
			if [ $? == 1 ]; then
				on_state=1
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
					on_state=0
				;;
				1) zenity --info --width=150 --text "修改失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		5)
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
							on_state=8
						fi
					fi
				;;
				1) on_state=0;;
			esac
		;;
		6)
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
EOF

			case $? in
				0) 
					zenity --info --width=150 --text "插入成功" 2> >(grep -v GtkDialog >&2)
				;;
				1) zenity --info --width=150 --text "插入失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		7)
			course_id=$(zenity --forms --title="删除课程"\
			--text="请输入课程课号"\
			--add-entry="课号" 2> >(grep -v GtkDialog >&2))

			if [ $? == 1 ]; then
				on_state=0
				continue
			fi

			$MYSQL -u$username -p$password homework <<EOF
delete from course where ID = '$course_id';
EOF
			
			case $? in
				0) 
					zenity --info --width=150 --text "删除成功" 2> >(grep -v GtkDialog >&2)
					on_state=0
				;;
				1) zenity --info --width=150 --text "删除失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		8)
			course_name=$(zenity --forms --width=300 --title="修改课程信息" --text="课号：$temp_course_id"\
			--add-entry="课程名" 2> >(grep -v GtkDialog >&2))
			if [ $? == 1 ]; then
				on_state=5
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
					on_state=0
				;;
				1) zenity --info --width=150 --text "修改失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		10)
			option=$(zenity --height=300 --width=280 --title="教师" --list --text "请选择要进行的操作" --radiolist  --column "选择" \
			--column "功能" FALSE "查看学生账号")
			
			if [ $? == 1 ]; then
				exit 0
			fi

			case $option in
				"查看学生账号") on_state=11;;
			esac
		;;
		20)
			option=$(zenity --height=300 --width=280 --title="教师" --list --text "请选择要进行的操作" --radiolist  --column "选择" \
			--column "功能" FALSE "查看学生账号")
			
			if [ $? == 1 ]; then
				exit 0
			fi

			case $option in
				"查看学生账号") on_state=11;;
			esac
		;;
	esac
done