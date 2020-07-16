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
	1) echo "user is a teacher"
	;;
	2) echo "user is a student"
	;;
	3)
		zenity --error --width 300 --text "账户类型错误"
		exit 1 
	;;
esac

while [ 1 == 1 ]
do
	case $on_state in
		0)
			option=$(zenity --height=300 --width=280 --title="管理员" --list --text "请选择要进行的操作" --radiolist  --column "选择" \
			--column "功能" FALSE "查看教师账号" FALSE "添加教师账号" FALSE "删除教师账号")
			
			if [ $? == 1 ]; then
				exit 0
			fi

			case $option in
				"查看教师账号") on_state=1;;
				"添加教师账号") on_state=2;;
				"删除教师账号") on_state=3;;
			esac
		;;
		1)
			teacher_content=$($MYSQL -u$username -p$password homework -Bse "select * from teachers;")
			zenity --list --title="教师账号列表" --height=600 --width=400 --column="工号" --column="姓名" $teacher_content
			case $? in
				0) on_state=0;;
				1) exit 0;;
			esac
		;;
		2)
			teacher_info=$(zenity --forms --title="添加教师"\
			--text="请输入教师账号信息"\
			--add-entry="工号"\
			--add-entry="姓名")
			if [ $? == 1 ]; then
				on_state=0
				continue
			fi
			teacher_id=$(echo $teacher_info | cut -d'|' -f1)
			teacher_name=$(echo $teacher_info | cut -d'|' -f2)
			if [ $teacher_id =="" ] || [ $teacher_name == "" ]; then
				
			fi
			$MYSQL -u$username -p$password homework <<EOF
insert into teachers values('$teacher_id', '$teacher_name');
insert into account values('$teacher_id', 1);
EOF
			case $? in
				0) 
					zenity --info --width=250 --text "插入成功"
					on_state=0
				;;
				1) zenity --info --width=250 --text "插入失败";;
			esac
		;;
	esac
done