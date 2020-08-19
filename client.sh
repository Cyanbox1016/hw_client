# 程序名：client.sh
# 作者：3180105481 王泳淇
# 功能：作业管理系统
#! /bin/bash

# ----------启动前初始化工作----------

# login_state：登陆状态  0表示登陆成功，1表示未登录或登录失败
let login_state=1
# 获取脚本文件所在路径，并将当前工作目录修改为脚本文件所在的路径
client_path=$(cd $(dirname $0); pwd)
# 获得mysql路径
MYSQL=$(which mysql)

# 管理员账号，用于进行一些全局初始化工作
root_id="root"
root_pswd="F0cus.0n"

# 若首次在本机器上使用，需要建立数据库和相关表
$MYSQL -u$root_id -p$root_pswd -e "create database if not exists homework;"

$MYSQL -u$root_id -p$root_pswd homework <<EOF
create table if not exists account (ID char(10) primary key, type decimal(1, 0));
create table if not exists course (ID char(12) primary key, name varchar(35));
create table if not exists students (ID char(10) primary key, name varchar(35));
create table if not exists teachers (ID char(10) primary key, name varchar(35));
create table if not exists stu_course (student_ID char(10), course_ID char(12));
create table if not exists teacher_course (teacher_ID char(10), course_ID char(12));
EOF

# 初次使用时，在account表中添加管理员账户信息
declare -i root_in
root_in=$($MYSQL -u $root_id -p$root_pswd homework -Bse "select ID from account where ID = '$root_id';" | wc -w)
if [ $root_in == 0 ]; then
	$MYSQL -u$username -p$password -e "insert into account values ('$root_id', 0);"
fi

# 用户登录，若登录失败则维持在当前登陆界面
while [ $login_state == 1 ]
do
	# 登录界面
	login=$(zenity  --username --password --ok-label="登录" --cancel-label="退出" --title "登录到作业系统")
	if [ $? != 0 ]
	then
		exit 0
	fi
	# 获取用户名和密码
	username=$(echo $login | cut -d'|' -f1)
	password=$(echo $login | cut -d'|' -f2)

	# 检查用户名和密码是否可以登录MySQL
	$MYSQL -u$username -p$password -e "exit"
	login_state=$?

	# 登录失败则报错
	if [ $login_state == 1 ]
	then
		zenity --error --width 300 --text "登录失败，请检查用户名和密码"
	fi
done

# user_type：账户类型. 0：管理员  1：教师  2：学生  3：错误类型
declare -i user_type=3
# on_state：系统状态机的状态变量，决定显示页面类型
declare -i on_state=0
# 获取用户账户类型
user_type=$($MYSQL -u $root_id -p$root_pswd -Bse "select type from homework.account where id ='$username'")

# 根据账户类型决定状态机的初始状态
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

# 初始化全局变量，这些全局变量用于暂存当前选中的教师、学生、课程等内容
temp_teacher_id=
temp_course_id=
present_course=
present_info=
present_hw=
present_stu=

# 状态机主程序
while [ 1 == 1 ]
do
	case $on_state in
		# 管理员账户功能界面
		0)
			# 列表显示功能选项
			option=$(zenity --height=300 --width=280 --title="管理员" --list --text "请选择要进行的操作" --radiolist  --column "选择" \
			--column "功能" FALSE "查询/修改教师账号信息" FALSE "添加教师账号"\
			FALSE "查询/修改课程信息" FALSE "添加课程")
			
			# 用户点击了关闭或取消，退出系统
			if [ $? == 1 ]; then
				exit 0
			fi

			# 根据用户选择的功能进入下一状态
			case $option in
				"查询/修改教师账号信息") on_state=1;;
				"添加教师账号") on_state=3;;
				"查询/修改课程信息") on_state=6;;
				"添加课程") on_state=7;;
			esac
		;;
		# 查询/修改教师账号信息：列表显示教师账号
		1)
			# 从MySQL中获取教师账号列表
			teacher_content=$($MYSQL -u$username -p$password homework -Bse "select * from teachers;")
			# 窗口输出教师账号列表，并获取用户的选择
			teacher_selected=$(zenity --list --title="教师账号列表" --ok-label="修改" --cancel-label="返回"\
			--text="可选中教师进行操作"\
			--height=600 --width=400 --column="工号" --column="姓名" $teacher_content)
			
			case $? in
				# 选择确定
				0) 
					# 选中一个教师，设为当前教师，并进入状态2
					if [ "$teacher_selected" != "" ]; then
						declare -i word;
						word=$($MYSQL -u$username -p$password homework -Bse "select name from teachers where ID = '$teacher_selected';" | wc -w)
						if [ $word != 0 ]; then
							temp_teacher_id=$teacher_selected
							on_state=2
						fi
					#未选中教师
					else
						zenity --info --width=250 --text "请选中一个教师" 2> >(grep -v GtkDialog >&2)
					fi
				;;
				# 选择取消
				1) on_state=0;;
			esac
		;;
		# 修改教师账号信息：功能列表
		2)
			# 列表显示可选功能并接受用户输入
			selected=$(zenity --height=300 --width=280 --title="修改教师账号信息" --list --text "请选择要进行的操作" --radiolist  --column "选择" \
			--column "功能" FALSE "修改教师姓名与账户密码" FALSE "绑定教师与课程" FALSE "解绑教师与课程" FALSE "删除教师")
			
			# 用户选择取消或关闭了窗口，退回上个页面
			if [ $? == 1 ]; then
				on_state=1
				continue
			fi
			
			# 根据用户选择的功能决定下一状态
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
		# 添加新的教师
		3)
			# 从窗口获取用户输入的教师信息
			teacher_info=$(zenity --forms --title="添加教师"\
			--text="请输入教师账号信息"\
			--text="姓名不得包含空格"\
			--add-entry="工号"\
			--add-entry="姓名"\
			--add-entry="密码" 2> >(grep -v GtkDialog >&2))

			# 用户选择了取消，回到开始的功能列表
			if [ $? == 1 ]; then
				on_state=0
				continue
			fi

			# 处理zenity获取的教师信息，从中提取信息
			teacher_id=$(echo $teacher_info | cut -d'|' -f1)
			teacher_name=$(echo $teacher_info | cut -d'|' -f2)
			teacher_passwd=$(echo $teacher_info | cut -d'|' -f3)

			# 若出现空白项，会造成后续显示时三个参数内容的错乱，必须避免这种情况
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

			# 向数据库中插入新教师信息
			$MYSQL -u$username -p$password homework <<EOF
create user '$teacher_id'@'localhost' identified by '$teacher_passwd';
grant all privileges on *.* to '$teacher_id'@'localhost' identified by '$teacher_passwd' with grant option;
grant CREATE USER on *.* to '$teacher_id'@'localhost' identified by '$teacher_passwd';
insert into teachers values('$teacher_id', '$teacher_name');
insert into account values('$teacher_id', 1);
EOF
			# 输出创建教师成功与否的信息，并决定下一状态
			case $? in
				0) 
					zenity --info --width=150 --text "创建成功" 2> >(grep -v GtkDialog >&2)
					on_state=0
				;;
				1) zenity --info --width=150 --text "创建失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		# 删除教师
		4)
			teacher_id=$temp_teacher_id

			# 弹窗确认是否确认删除，若选择取消则退回到状态2
			zenity --question --text "确定要删除该教师吗？"
			if [ $? == 1 ]; then
				on_state=2
				continue
			fi

			# 在数据库中删除该教师信息
			$MYSQL -u$username -p$password homework <<EOF
delete from teachers where ID = '$teacher_id';
delete from account where id = '$teacher_id';
delete from mysql.user where User = '$teacher_id';
drop user '$teacher_id'@'localhost';
flush privileges;
EOF
			# 输出删除教师成功与否的信息，并返回状态1
			case $? in
				0) 
					zenity --info --width=150 --text "删除成功" 2> >(grep -v GtkDialog >&2)
					on_state=1
				;;
				1) 
					zenity --info --width=150 --text "删除失败" 2> >(grep -v GtkDialog >&2)
				   	on_state=1
				;;
			esac
		;;
		# 修改现有的教师信息
		5)
			# 从窗口获取修改后的教师信息
			teacher_info=$(zenity --forms --width=300 --title="修改教师信息" --text="工号：$temp_teacher_id"\
			--text="姓名不得包含空格"\
			--add-entry="姓名"\
			--add-entry="密码" 2> >(grep -v GtkDialog >&2))

			# 用户选择取消，返回状态2
			if [ $? == 1 ]; then
				on_state=2
				continue
			fi

			# 分割用|隔开的用户输入
			teacher_name=$(echo $teacher_info | cut -d'|' -f1)
			teacher_passwd=$(echo $teacher_info | cut -d'|' -f2)

			# 避免用户输入的内容有空
			if [ "$teacher_name" == "" ]; then
				zenity --info --width=250 --text "姓名不能为空" 2> >(grep -v GtkDialog >&2)
				continue
			elif [ "$teacher_passwd" == "" ]; then
				zenity --info --width=250 --text "密码不能为空" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			# 修改数据库中的教师信息
			$MYSQL -u$username -p$password homework <<EOF
update teachers set name = '$teacher_name' where ID = '$temp_teacher_id';
set password for '$temp_teacher_id'@'localhost' = password('$teacher_passwd');
flush privileges;
EOF
			# 显示修改信息成功与否，并决定下一状态
			case $? in
				0) 
					zenity --info --width=150 --text "修改成功" 2> >(grep -v GtkDialog >&2)
					on_state=1
				;;
				1) zenity --info --width=150 --text "修改失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		# 管理课程信息：列表显示系统课程
		6)
			# 从数据库中获取系统课程
			course_content=$($MYSQL -u$username -p$password homework -Bse "select * from course;")
			# 窗口输出系统课程列表，并从中获取用户选择
			course_selected=$(zenity --list --title="课程列表" --height=600 --width=400 --column="课号" --column="课程名" $course_content)
			
			case $? in
				# 用户选择确定
				0) 
					on_state=0
					# 选定当前课程，进入状态8
					if [ "$course_selected" != "" ]; then
						declare -i word;
						word=$($MYSQL -u$username -p$password homework -Bse "select name from course where ID = '$course_selected';" | wc -w)
						if [ $word != 0 ]; then
							temp_course_id=$course_selected
							present_course=$course_selected
							on_state=8
						fi
					# 没有课程被选中
					else
						zenity --info --width=250 --text "请选中一门课程" 2> >(grep -v GtkDialog >&2)
					fi
				;;
				# 用户选择退出，回到状态0
				1) on_state=0;;
			esac
		;;
		# 添加新课程
		7)
			# 从窗口读取新建课程信息
			course_info=$(zenity --forms --title="添加课程"\
			--text="请输入课程信息"\
			--add-entry="课号"\
			--add-entry="课程名" 2> >(grep -v GtkDialog >&2))
			
			# 用户选择取消，退回到0状态
			if [ $? == 1 ]; then
				on_state=0
				continue
			fi

			# 处理zenity输出的由|分隔开的字符串
			course_id=$(echo $course_info | cut -d'|' -f1)
			course_name=$(echo $course_info | cut -d'|' -f2)

			# 当有内容为空时报错
			if [ "$course_id" == "" ]; then
				zenity --info --width=250 --text "课号不能为空" 2> >(grep -v GtkDialog >&2)
				continue
			elif [ "$course_name" == "" ]; then
				zenity --info --width=250 --text "课程名不能为空" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			# 向数据库内加入新建的课程
			$MYSQL -u$username -p$password homework <<EOF
insert into course values('$course_id', '$course_name');
create table info_$course_id (timestamp char(10) primary key, issue_date date, title varchar(50), content_path varchar(65));
create table stu_$course_id (ID char(10) primary key, name varchar(35));
create table hw_$course_id (timestamp char(10) primary key, title varchar(50), type char(10), issue_date date, due_date date, content_path varchar(65));
EOF
			
			# 显示是否添加成功，并决定下一状态
			case $? in
				0) 
					zenity --info --width=150 --text "插入成功" 2> >(grep -v GtkDialog >&2)
				;;
				1) zenity --info --width=150 --text "插入失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		# 修改课程信息：功能列表
		8)
			# 窗口列表显示可选功能，并获取用户输入
			selected=$(zenity --height=300 --width=280 --title="修改课程信息" --list --text "请选择要进行的操作" --radiolist  --column "选择" \
			--column "功能" FALSE "修改课程名" FALSE "绑定教师与课程" FALSE "解绑教师与课程" FALSE "删除课程")
			
			# 用户选择取消，回到状态6
			if [ $? == 1 ]; then
				on_state=6
				continue
			fi
			
			# 根据用户选项决定下一状态
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
		# 修改课程名
		9)
			# 从窗口获取用户输入的新课程名
			course_name=$(zenity --forms --width=300 --title="修改课程名" --text="课号：$temp_course_id"\
			--add-entry="课程名" 2> >(grep -v GtkDialog >&2))
			
			# 用户选择取消，返回状态8
			if [ $? == 1 ]; then
				on_state=8
				continue
			fi

			# 若输入为空则报错
			if [ "$course_name" == "" ]; then
				zenity --info --width=250 --text "课程名不能为空" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			# 更新数据库中的课程名
			$MYSQL -u$username -p$password homework <<EOF
update course set name = '$course_name' where ID = '$temp_course_id';
EOF

			# 显示是否修改成功，并决定下一状态
			case $? in
				0) 
					zenity --info --width=150 --text "修改成功" 2> >(grep -v GtkDialog >&2)
					on_state=6
				;;
				1) zenity --info --width=150 --text "修改失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		# 删除课程
		10)
			course_id=$temp_course_id

			# 确认是否删除课程
			zenity --question --text "确定要删除该课程吗？"

			# 用户选择取消，返回状态8
			if [ $? == 1 ]; then
				on_state=8
				continue
			fi

			# 获取当前课程所有作业的学生提交记录表
			hw_table_list=($($MYSQL -u$username -p$password homework -Bse "select TABLE_NAME from INFORMATION_SCHEMA.TABLES where TABLE_SCHEMA='homework' and TABLE_NAME like '${course_id}_hw_%';"))
			
			# 删除数据库中相关表和数据
			if [ ${#hw_table_list[@]} != 0 ]; then
				$MYSQL -u$username -p$password homework <<EOF
delete from course where ID = '$course_id';
drop table info_$course_id;
drop table stu_$course_id;
drop table hw_$course_id;
EOF
				for(( i=0; i<${#hw_table_list[@]}; i++ ))
				do
					$MYSQL -u$username -p$password homework <<EOF
drop table ${hw_table_list[$i]};
EOF
				done
			else
				$MYSQL -u$username -p$password homework <<EOF
delete from course where ID = '$course_id';
drop table info_$course_id;
drop table stu_$course_id;
drop table hw_$course_id;
EOF
			fi
			
			# 显示是否删除成功，并决定下一状态
			case $? in
				0) 
					zenity --info --width=150 --text "删除成功" 2> >(grep -v GtkDialog >&2)
					on_state=6
				;;
				1) zenity --info --width=150 --text "删除失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		# 绑定教师与课程（从教师进入）
		11)
			# 从数据库获取课程信息
			course_content=$($MYSQL -u$username -p$password homework -Bse "select * from course;")
			# 列表显示课程，并获取用户选择
			course_selected=$(zenity --list --title="课程列表" --text="请选择要绑定的课程"\
			--ok-label="绑定" --cancel-label="取消" --height=600 --width=400 --column="课号" --column="课程名" $course_content)

			# 用户选择取消，返回状态2
			if [ $? == 1 ]; then
				on_state=2
				continue
			fi

			# 用户未选择课程就点击了确定
			if [ "$course_selected" == "" ]; then
				zenity --info --width=250 --text "请选择要绑定的课程" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			# 若当前教师和该课程还没有绑定过，在数据库中添加（教师，课程）对，记录教师和课程的绑定关系
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
			# 若已经绑定过，则提示已经绑定过，不再做其他处理	 
			else
				zenity --info --width=350 --text "该教师和该课程已经被绑定过，无需绑定" 2> >(grep -v GtkDialog >&2)
			fi
		;;
		# 解绑教师与课程（从教师进入）
		12)
			# 从数据库中获取已经和该教师绑定的课程
			course_binded=$($MYSQL -u$username -p$password homework -Bse "select * from course where ID in (select course_ID from teacher_course where teacher_ID = '$temp_teacher_id');")
			# 列表显示课程，并获取用户的选择
			course_selected=$(zenity --list --title="课程列表" --text="请选择要解绑的课程"\
			--ok-label="解绑" --cancel-label="取消" --height=600 --width=400 --column="课号" --column="课程名" $course_binded)

			# 用户选择取消，回到状态2
			if [ $? == 1 ]; then
				on_state=2
				continue
			fi

			# 用户没有选择课程即点击确定，报错
			if [ "$course_selected" == "" ]; then
				zenity --info --width=250 --text "请选择要解绑的课程" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			# 在数据库中删除教师和课程的绑定信息
			$MYSQL -u$username -p$password homework <<EOF
delete from teacher_course where teacher_ID = '$temp_teacher_id' and course_ID = '$course_selected';
EOF
			
			# 显示是否绑定成功
			case $? in
				0) 
					zenity --info --width=150 --text "解绑成功" 2> >(grep -v GtkDialog >&2)
				;;
				1) zenity --info --width=150 --text "解绑失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		# 绑定教师与课程（从课程进入）
		13)
			# 从数据库中获取教师列表
			teacher_content=$($MYSQL -u$username -p$password homework -Bse "select * from teachers;")
			# 列表显示教师，并获取用户选择项
			teacher_selected=$(zenity --list --title="教师账号列表" --ok-label="绑定" --cancel-label="取消"\
			--text="选择要绑定的教师"\
			--height=600 --width=400 --column="工号" --column="姓名" $teacher_content)

			case $? in
				0) 
					if [ "$teacher_selected" != "" ]; then
						declare -i word;
						word=$($MYSQL -u$username -p$password homework -Bse "select teacher_ID from teacher_course where teacher_ID = '$teacher_selected' and course_ID = '$present_course';" | wc -w)
						if [ $word == 0 ]; then
							# 在数据库添加教师和课程的绑定信息
							$MYSQL -u$username -p$password homework <<EOF
insert into teacher_course values('$teacher_selected', '$present_course');
EOF

							case $? in
								0) 
									zenity --info --width=150 --text "绑定成功" 2> >(grep -v GtkDialog >&2)
									on_state=8
								;;
								1) 
									zenity --info --width=150 --text "绑定失败" 2> >(grep -v GtkDialog >&2)
								;;
							esac
						# 该教师和课程已经绑定过，输出已绑定的信息，不作其他处理
						else
							zenity --info --width=350 --text "该教师和该课程已经被绑定过，无需绑定" 2> >(grep -v GtkDialog >&2)

						fi
					# 用户未选择教师就点击了确定
					else
						zenity --info --width=250 --text "请选中一个教师" 2> >(grep -v GtkDialog >&2)
					fi
				;;
				# 用户选择取消
				1) on_state=8;;
			esac
		;;
		# 解绑教师与课程（从课程进入）
		14)
			# 从数据库获取和该课程绑定的教师
			teacher_content=$($MYSQL -u$username -p$password homework -Bse "select * from teachers where ID in (select teacher_ID from teacher_course where course_ID = '$present_course');")
			# 输出教师列表，并获取用户选择项
			teacher_selected=$(zenity --list --title="教师账号列表" --ok-label="解绑" --cancel-label="取消"\
			--text="选择要解绑的教师"\
			--height=600 --width=400 --column="工号" --column="姓名" $teacher_content)

			# 用户选择取消，返回状态8
			if [ $? == 1 ]; then
				on_state=8
				continue
			fi

			# 用户未选择教师即点击确定，报错返回
			if [ "$teacher_selected" == "" ]; then
				zenity --info --width=250 --text "请选择要解绑的课程" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			# 从数据库中删除教师与课程的绑定信息
			$MYSQL -u$username -p$password homework <<EOF
delete from teacher_course where teacher_ID = '$teacher_selected' and course_ID = '$present_course';
EOF
			
			# 显示是否解绑成功，并决定下一状态
			case $? in
				0) 
					zenity --info --width=150 --text "解绑成功" 2> >(grep -v GtkDialog >&2)
					on_state=8
				;;
				1) zenity --info --width=150 --text "解绑失败" 2> >(grep -v GtkDialog >&2);;
			esac

		;;
		# 教师，选择要处理的课程
		15)
			# 从数据库中获得课程信息并处理格式
			course_id=($($MYSQL -u$username -p$password homework -Bse "select ID from course where ID in (select course_id from teacher_course where \
				teacher_id = '$username');"))
			course_name=($($MYSQL -u$username -p$password homework -Bse "select name from course where ID in (select course_id from teacher_course where \
				teacher_id = '$username');"))
			course_list=()
			for(( i=0; i<${#course_id[@]}; i++ ))
			do
				course_list+=(FALSE "${course_id[$i]}" "${course_name[$i]}")
			done

			# 窗口输出课程列表并获得用户输入
			option=$(zenity --height=500 --width=400 --title="教师" --list --text "请选择要管理的课程" --radiolist  --column "选择" \
			--column "课号" --column "课程名" "${course_list[@]}")

			# 用户选择退出系统
			if [ $? == 1 ]; then
				exit 0
			fi

			# 用户未选择课程即点击了确定
			if [ "$option" == "" ]; then
				zenity --info --width=150 --text "请选择要管理的课程" 2> >(grep -v GtkDialog >&2)
				continue
			# 设定选择课程为当前课程，进入功能列表
			else
				present_course=$option
				on_state=16
			fi
		;;
		# 教师功能列表
		16)
			# 列表显示待选功能，并获取用户输入
			option=$(zenity --height=400 --width=280 --title="教师" --list --text "当前课程：$present_course" --radiolist  --column "选择" \
			--column "功能" FALSE 创建学生账号 FALSE 查询学生账号 FALSE 导入学生账号 FALSE 删除课程学生 FALSE 新建课程信息 FALSE 管理课程信息 FALSE 新建作业/实验  FALSE 管理作业/实验)

			# 用户选择取消，返回课程选择页面
			if [ $? == 1 ]; then
				on_state=15
				continue
			fi

			# 根据用户选项决定下一状态
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
		# 新建课程
		17)
			# 从窗口读入用户输入的课程信息内容
			info=$(yad --center --width=400 --height=500 -margin=15 \
			--title="新建课程信息" --text="请输入课程信息" \
			--form --date-format="%y-%m-%d" \
			--field="标题" \
			--field="日期":DT \
			--field="内容":TXT)

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=16
				continue
			fi

			# 为了分割多项内容且避免丢失内容中的空格，将空格替换为^^^，将|替换为空格并分开处理
			info_content=${info// /^^^}
			info_content=${info_content//|/ }
			info_con=($info_content)

			if [[ ${#info_con[@]} < 3 ]]; then
				zenity --info --width=150 --text "不允许有空栏" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			# 分割输入的多项内容，并替换回空格
			info_title="${info_con[0]//^^^/ }"
			info_date="${info_con[1]//^^^/ }"
			info_content="${info_con[2]//^^^/ }"
			timestamp=$(date +%s)

			# 建立公告存储目录
			if ! [ -d $client_path/info ]; then
				mkdir $client_path/info
			fi

			# 建立本课程公告存储的子目录
			if ! [ -d $client_path/info/info_$present_course ]; then
				mkdir $client_path/info/info_$present_course
			fi

			# 建立文件存储课程公告内容
			touch "$client_path/info/info_$present_course/$timestamp"
			printf "$info_content" > "$client_path/info/info_$present_course/$timestamp"
			content_path="$client_path/info/info_$present_course/$timestamp"

			# 在数据库中添加课程公告信息
			$MYSQL -u$username -p$password homework <<EOF
insert into info_$present_course values('$timestamp', '$info_date', '$info_title', '$content_path');
EOF
			# 显示是否创建课程信息成功
			case $? in
				0) zenity --info --width=150 --text "创建成功" 2> >(grep -v GtkDialog >&2);;
				1) zenity --info --width=150 --text "创建失败" 2> >(grep -v GtkDialog >&2);;
			esac

			on_state=16
		;;
		# 管理课程信息：列表显示课程信息
		18)
			# 从数据库中获得课程信息列表，并对格式进行处理
			title_all=$($MYSQL -u$username -p$password homework -Bse "select title from info_$present_course;")
			title_all=${title_all// /^^^}
			title=($title_all)

			date=($($MYSQL -u$username -p$password homework -Bse "select issue_date from info_$present_course;"))
			timestamp=($($MYSQL -u$username -p$password homework -Bse "select timestamp from info_$present_course;"))
			info_list=()
			for ((i=0; i<${#title[@]}; i++)); do
				info_list+=("${timestamp[$i]}" "${date[$i]}" "${title[$i]//^^^/ }")
			done

			# 列表显示课程信息，并获取用户选择
			info_selected=$(zenity --list --title="公告列表" --text="请选择要处理的课程信息/公告"\
			--height=600 --width=400 --column="编号" --column="日期" --column="标题" "${info_list[@]}")

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=16
				continue
			fi

			#  用户未选择课程信息就点击了确定
			if [ "$info_selected" == "" ]; then
				zenity --info --width=150 --text "请选择要处理的课程信息" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			# 确定选择的课程信息为当前课程信息，并进入状态19
			present_info=$info_selected
			on_state=19
		;;
		# 选择功能：编辑公告或删除公告
		19)
			# 列表显示功能并获取用户选择
			selected=$(zenity --height=300 --width=280 --title="修改公告" --list --text "请选择要进行的操作" --radiolist  --column "选择" \
			--column "功能" FALSE "编辑公告内容" FALSE "删除公告")
			
			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=18
				continue
			fi
			
			# 根据用户选择的功能确定下一状态
			case $selected in
				"编辑公告内容")
					on_state=20
				;;
				"删除公告")
					on_state=21
				;;
			esac
		;;
		# 修改课程信息
		20)
			# 从数据库中获得该公告的信息，并从文件中读取公告内容
			pre_date="$($MYSQL -u$username -p$password homework -Bse "select issue_date from info_$present_course where timestamp='$present_info';")"
			pre_title="$($MYSQL -u$username -p$password homework -Bse "select title from info_$present_course where timestamp='$present_info';")"
			pre_path="$($MYSQL -u$username -p$password homework -Bse "select content_path from info_$present_course where timestamp='$present_info';")"
			pre_content="$(cat "$pre_path")"
			
			# 在窗口中显示现有的公告内容，并读取用户修改后的公告内容
			info=$(yad --center --width=400 --height=500 -margin=15 \
			--title="修改课程信息" --text="请输入课程信息" \
			--form --date-format="%y-%m-%d" \
			--field="标题" \
			--field="日期":DT \
			--field="内容":TXT \
			"$pre_title" "$pre_date" "$pre_content")

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=19
				continue
			fi

			# 格式化处理输入的内容
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

			# 删除原有的公告文件，存储新的公告文件
			rm -f "$client_path/info/info_$present_course/$timestamp"
			touch "$client_path/info/info_$present_course/$timestamp"
			printf "$info_content" > "$client_path/info/info_$present_course/$timestamp"
			content_path="$client_path/info/info_$present_course/$timestamp"

			# 从数据库中删除原有的公告信息，并加入新的公告信息
			$MYSQL -u$username -p$password homework <<EOF
delete from info_$present_course where timestamp='$timestamp';
insert into info_$present_course values('$timestamp', '$info_date', '$info_title', '$content_path');
EOF
			# 显示是否修改成功
			case $? in
				0) zenity --info --width=150 --text "修改成功" 2> >(grep -v GtkDialog >&2);;
				1) zenity --info --width=150 --text "修改失败" 2> >(grep -v GtkDialog >&2);;
			esac

			on_state=18;
		;;
		# 删除公告
		21)
			# 弹窗确认是否要删除公告
			zenity --question --title "删除公告" --text "确定要删除该公告吗？"

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=18
				continue
			fi

			# 获取公告文件位置
			info_file="$($MYSQL -u$username -p$password homework -Bse "select content_path from info_$present_course where timestamp='$present_info';")"

			# 删除公告文件，并从数据库中删除信息
			rm "$info_file"
			$MYSQL -u$username -p$password homework <<EOF
delete from info_$present_course where timestamp = '$present_info';
EOF
			# 显示是否删除成功，并决定下一状态
			case $? in
				0) 
					zenity --info --width=150 --text "删除成功" 2> >(grep -v GtkDialog >&2)
					on_state=18
				;;
				1) zenity --info --width=150 --text "删除失败" 2> >(grep -v GtkDialog >&2);;
			esac
			
		;;
		# 按账号查询学生，并可选择将学生加入课程或修改学生信息
		22)
			# 从窗口读取输入的学生账号
			id=$(zenity --entry --text "输入待查询的学生账号");

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=16
				continue
			fi

			# 从数据库中查询对应的学生信息
			stu=($($MYSQL -u$username -p$password homework -Bse "select * from students where ID='$id';"))
			stu_list=()

			# 格式化学生信息，在前面加上FALSE，便于在窗口输出
			if [ ${#stu[@]} != 0 ]; then
				stu_list=(FALSE "${stu[@]}")
			fi

			# 列表显示查找到的学生，并获取选择
			student_selected=$(zenity --height=300 --width=280 --title="学生查询" --list --text "可选择学生加入课程" --checklist --ok-label="操作" --cancel-label="返回" --column "选择" \
			--column "学号" --column "姓名" ${stu_list[@]})

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=16
				continue
			fi

			# 用户选择操作，但没有勾选学生
			if [ "$student_selected" = "" ]; then
				zenity --info --width=150 --text "请选择至少一个学生" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			present_stu=$student_selected

			option=$(zenity --height=400 --width=280 --title="选择学生" --list --text "当前学生：$present_stu" --radiolist  --column "选择" \
			--column "功能" FALSE 修改学生信息 FALSE 添加学生到本课程)

			# 用户选择取消
			if [ $? == 1 ]; then
				continue
			fi

			# 根据用户输入决定下一状态
			case $option in
				"添加学生到本课程")
					# 将用户勾选的学生加入数据库
					if [ $($MYSQL -u$username -p$password homework -Bse "select * from stu_$present_course where ID = '$present_stu';" | wc -w) == 0 ]; then
					$MYSQL -u$username -p$password homework <<EOF
insert into stu_$present_course select * from students where ID = '$student_selected';
insert into stu_course values('$student_selected', '$present_course');
EOF
					fi
					# 显示是否成功的信息，并决定下一状态
					case $? in
						0) 
							zenity --info --width=150 --text "加入成功" 2> >(grep -v GtkDialog >&2)
							on_state=16
						;;
						1) zenity --info --width=150 --text "加入失败" 2> >(grep -v GtkDialog >&2);;
					esac
				;;
				"修改学生信息")
					# 从窗口获取修改后的学生信息
					student_info=$(zenity --forms --width=300 --title="修改学生信息" --text="学号：$present_stu"\
					--text="姓名不得包含空格"\
					--add-entry="姓名"\
					--add-entry="密码" 2> >(grep -v GtkDialog >&2))

					# 用户选择取消，返回状态16
					if [ $? == 1 ]; then
						on_state=16
						continue
					fi

					# 分割用|隔开的用户输入
					stu_name=$(echo $student_info | cut -d'|' -f1)
					stu_passwd=$(echo $student_info | cut -d'|' -f2)

					# 避免用户输入的内容有空
					if [ "$stu_name" == "" ]; then
						zenity --info --width=250 --text "姓名不能为空" 2> >(grep -v GtkDialog >&2)
						continue
					elif [ "$stu_passwd" == "" ]; then
						zenity --info --width=250 --text "密码不能为空" 2> >(grep -v GtkDialog >&2)
						continue
					fi

					# 修改数据库中的学生信息
					$MYSQL -u$username -p$password homework <<EOF
update students set name = '$stu_name' where ID = '$present_stu';
set password for '$present_stu'@'localhost' = password('$stu_passwd');
flush privileges;
EOF
					# 显示修改信息成功与否，并决定下一状态
					case $? in
						0) 
							zenity --info --width=150 --text "修改成功" 2> >(grep -v GtkDialog >&2)
							on_state=16
						;;
						1) zenity --info --width=150 --text "修改失败" 2> >(grep -v GtkDialog >&2);;
					esac

					on_state=16
				;;
				*)
					on_state=16
				;;
			esac

		;;
		# 批量导入课程学生
		220)
			# 从数据库中获取还没有加入该课程的学生列表
			stu_id=($($MYSQL -u$username -p$password homework -Bse "select ID from students where ID not in (select ID from stu_$present_course);"))
			# 处理学生数据，在前面添加FALSE以便于窗口输出
			stu_name=($($MYSQL -u$username -p$password homework -Bse "select name from students where ID not in (select ID from stu_$present_course);"))
			stu_list=()

			for ((i=0; i<${#stu_id[@]}; i++)); do
				stu_list+=(FALSE ${stu_id[$i]} ${stu_name[$i]})
			done

			# 窗口输出学生列表并读取用户选择
			student_selected=$(zenity --height=300 --width=280 --title="学生查询" --list --text "可选择学生加入课程" --checklist --ok-label="添加" --cancel-label="返回" --column "选择" \
			--column "学号" --column "姓名" ${stu_list[@]})

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=16
				continue
			fi

			# 格式化处理用户选择的学生列表
			student_selected=${student_selected//|/ }
			student_list=($student_selected)

			# 将选中的学生导入数据库
			for ((i=0; i<${#student_list[@]}; i++)); do
				$MYSQL -u$username -p$password homework <<EOF
insert into stu_$present_course select * from students where ID = '${student_list[$i]}';
insert into stu_course values('${student_list[$i]}', '$present_course');
EOF
			done

			# 显示是否成功的信息，并决定下一状态
			case $? in
				0) 
					zenity --info --width=150 --text "插入成功" 2> >(grep -v GtkDialog >&2)
					on_state=16
				;;
				1) zenity --info --width=150 --text "插入失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		# 创建学生账号
		23)
			# 从窗口读入学生账号信息
			stu_info=$(zenity --forms --title="创建学生账号"\
			--text="请输入学生账号信息"\
			--add-entry="学号"\
			--add-entry="姓名"\
			--add-entry="密码" 2> >(grep -v GtkDialog >&2))

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=16
				continue
			fi
			# 分割学生信息中的各项
			stu_id=$(echo $stu_info | cut -d'|' -f1)
			stu_name="$(echo $stu_info | cut -d'|' -f2)"
			stu_passwd=$(echo $stu_info | cut -d'|' -f3)

			# 若有空栏则报错
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

			# 向数据库中加入该学生账户，并将该学生加入到本课程中
			$MYSQL -u$username -p$password homework <<EOF
create user '$stu_id'@'localhost' identified by '$stu_passwd';
grant all privileges on homework.* to '$stu_id'@'localhost' identified by '$stu_passwd';
insert into students values('$stu_id', '$stu_name');
insert into account values('$stu_id', 2);
insert into stu_$present_course values('$stu_id', '$stu_name');
insert into stu_course values('$stu_id', '$present_course');
EOF
			# 显示是否成功的信息，并决定下一状态
			case $? in
				0) 
					zenity --info --width=150 --text "创建成功" 2> >(grep -v GtkDialog >&2)
					on_state=16
				;;
				1) zenity --info --width=150 --text "创建失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		# 删除课程学生
		230)
			# 从数据库中获取当前课程的学生信息，并处理格式便于显示
			stu_id=($($MYSQL -u$username -p$password homework -Bse "select ID from stu_$present_course;"))
			stu_name=$($MYSQL -u$username -p$password homework -Bse "select name from stu_$present_course;")
			stu_name=${stu_name// /^^^}
			name_list=($stu_name)
			stu_list=()

			for ((i=0; i<${#stu_id[@]}; i++)); do
				stu_list+=(FALSE "${stu_id[$i]}" "${name_list[$i]//^^^/ }")
			done

			# 列表显示学生信息并读取用户选择
			student_selected=$(zenity --height=500 --width=400 --title="学生查询" --list --text "可从课程中删除学生" --checklist --ok-label="删除" --cancel-label="返回" --column "选择" \
			--column "学号" --column "姓名" ${stu_list[@]})

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=16
				continue
			fi

			student_selected=${student_selected// /^^^}
			student_selected=${student_selected//|/ }
			student_selected_list=($student_selected)

			# 从数据库删除学生信息
			for ((i=0; i<${#student_selected_list[@]}; i++)); do
				$MYSQL -u$username -p$password homework <<EOF
delete from stu_course where student_ID = '${student_selected_list[$i]//^^^/ }' and course_ID = '$present_course';
delete from stu_$present_course where ID = '${student_selected_list[$i]//^^^/ }';
EOF
			done

			# 删除该学生提交过的作业信息
			hw_list=($($MYSQL -u$username -p$password homework -Bse "select timestamp from hw_$present_course;"))

			for ((i=0; i<${#hw_list[@]}; i++)); do
				$MYSQL -u$username -p$password homework <<EOF
delete from ${present_course}_hw_${hw_list[$i]} where stu_ID = '${student_selected_list[$i]//^^^/ }';
EOF
			done

			# 显示是否成功的信息，并决定下一状态
			case $? in
				0) 
					zenity --info --width=150 --text "删除成功" 2> >(grep -v GtkDialog >&2)
					on_state=16
				;;
				1) zenity --info --width=150 --text "删除失败" 2> >(grep -v GtkDialog >&2);;
			esac
			
		;;
		# 新建作业或实验
		24)
			# 从窗口读取作业或实验的内容
			hw=$(yad --center --width=400 --height=500 -margin=15 \
			--title="新建作业/实验" --text="请输入作业/实验信息" \
			--form --date-format="%y-%m-%d" \
			--field="标题" \
			--field="类型":CB \
			--field="发布日期":DT \
			--field="截止日期":DT \
			--field="内容":TXT \
			"" "作业!实验" "" "" "" )

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=16
				continue
			fi

			# 格式化处理作业要求内容
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

			# 创建全局作业文件夹
			if ! [ -d $client_path/hw ]; then
				mkdir $client_path/hw
			fi

			# 创建本课程作业文件夹
			if ! [ -d $client_path/hw/hw_$present_course ]; then
				mkdir $client_path/hw/hw_$present_course
			fi

			# 将本作业或实验信息存储到文件中
			touch "$client_path/hw/hw_$present_course/$timestamp"
			mkdir "$client_path/hw/hw_$present_course/stu_$timestamp"
			printf "$hw_content" > "$client_path/hw/hw_$present_course/$timestamp"
			content_path="$client_path/hw/hw_$present_course/$timestamp"

			# 将本条作业/实验存储到数据库中
			$MYSQL -u$username -p$password homework <<EOF
insert into hw_$present_course values('$timestamp', '$hw_title', '$hw_type',  '$hw_issue_date', '$hw_due_date', '$content_path');
create table ${present_course}_hw_$timestamp(stu_id varchar(35), file_path varchar(120), point numeric(3));
EOF
			# 显示是否成功的信息，并决定下一状态
			case $? in
				0) 
					zenity --info --width=150 --text  "创建成功" 2> >(grep -v GtkDialog >&2)
					on_state=16
				;;
				1) zenity --info --width=150 --text "创建失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		# 管理作业/实验：当前课程作业/实验列表
		25)
			# 从数据库中获取当前课程的实验和作业信息，并对其进行格式化处理
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

			# 列表显示作业和实验，并读取用户选择
			hw_selected=$(zenity --list --title="作业/实验列表" --text="请选择要处理的课程作业/实验"\
			--height=600 --width=400 --column="编号" --column="标题" --column="发布日期" --column="截止日期" "${hw_list[@]}")

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=16
				continue
			fi

			# 用户没有选中作业或实验即点击确定
			if [ "$hw_selected" == "" ]; then
				zenity --info --width=150 --text "请选择要处理的作业/实验" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			# 选取作业设为当前作业，并进入状态26
			present_hw=$hw_selected
			on_state=26
		;;
		# 管理作业/实验：功能列表
		26)
			# 列表显示待选功能，并获取用户输入列表显示
			selected=$(zenity --height=300 --width=280 --title="处理作业/实验" --list --text "请选择要进行的操作" --radiolist  --column "选择" \
			--column "功能" FALSE "批阅作业" FALSE "修改要求" FALSE "删除作业")
			
			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=25
				continue
			fi
			
			# 根据用户选择确定下一状态
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
		# 批阅学生作业
		27)
			# 从数据库中选择已交作业的学生，并进行格式化处理
			stu_id=$($MYSQL -u$username -p$password homework -Bse "select stu_id from ${present_course}_hw_$present_hw;")
			path_all=$($MYSQL -u$username -p$password homework -Bse "select file_path from ${present_course}_hw_$present_hw;")
			path_all=${path_all// /^^^}
			path=($path_all)

			stu_hw_list=()
			for ((i=0; i<${#stu_id[@]}; i++)); do
				stu_name=$($MYSQL -u$username -p$password homework -Bse "select name from students where ID = '${stu_id[$i]}';")
				stu_hw_list+=("${stu_id[$i]}" "$stu_name" "${path[$i]//^^^/ }")
			done

			# 从数据库选取未交作业的学生，并进行格式化处理
			not_submit=($($MYSQL -u$username -p$password homework -Bse "select ID from stu_$present_course where ID not in (select stu_id from ${present_course}_hw_$present_hw);"))
			n_submit=()
			for ((i=0; i<${#not_submit[@]}; i++)); do
				stu_name=$($MYSQL -u$username -p$password homework -Bse "select name from students where ID = '${not_submit[$i]}';")
				n_submit+=("${not_submit[$i]}" "$stu_name" "未提交")
			done

			# 输出学生提交的作业列表，并读取用户输入
			id_selected=$(zenity --list --title="学生列表" --text="请选择要批阅的学生作业"\
			--ok-label="批阅" --cancel-label="取消" --height=600 --width=400 --column="学号" --column="姓名" --column="作业路径" "${stu_hw_list[@]}" "${n_submit[@]}")

			# 用户选择了取消
			if [ $? == 1 ]; then
				on_state=26
				continue
			fi

			# 未选中作业
			if [ "$id_selected" == "" ]; then
				zenity --info --width=150 --text "请选中要批阅的作业" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			# 该学生并未交作业，不能批改
			if [ $($MYSQL -u$username -p$password homework -Bse "select stu_id from ${present_course}_hw_$timestamp where stu_id = '$id_selected';" | wc -w) == 0 ]; then
				zenity --info --width=150 --text "该学生尚未提交作业" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			# 设置选中的学生为当前学生，并跳转到状态270
			present_stu="$id_selected"
			on_state=270
	
		;;
		# 批改作业
		270)
			# 在图形窗口中打开学生提交作业的目录
			path="$($MYSQL -u$username -p$password homework -Bse "select file_path from ${present_course}_hw_$present_hw where stu_id = '$present_stu';" )"
			xdg-open "$path"

			# 读取用户输入的分数
			score=$(zenity --entry --text="请输入分数")

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=27
			fi

			# 在数据库中更新分数
			$MYSQL -u$username -p$password homework <<EOF
update ${present_course}_hw_$timestamp set point=$score where stu_id = '$present_stu' ;
EOF
			# 显示是否成功的信息，并决定下一状态
			case $? in
				0) 
					zenity --info --width=150 --text  "批改成功" 2> >(grep -v GtkDialog >&2)
					on_state=27
				;;
				1) zenity --info --width=150 --text "批改失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		# 修改作业/实验要求
		28)
			# 从数据库中获取当前的作业信息，并从文件中读取作业要求内容
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

			# 窗口显示当前作业/实验要求内容，并读取用户修改后的内容
			hw=$(yad --center --width=400 --height=500 -margin=15 \
			--title="新建作业/实验" --text="请输入作业/实验信息" \
			--form --date-format="%y-%m-%d" \
			--field="标题" \
			--field="类型":CB \
			--field="发布日期":DT \
			--field="截止日期":DT \
			--field="内容":TXT \
			"$pre_title" "$pre_type" "$pre_issue" "$pre_due" "$pre_content" )

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=26
				continue
			fi

			# 格式化处理用户输入的作业/实验内容
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

			# 删除此前存储的作业/实验要求文件，并将新内容写入新文件中
			rm -f "$client_path/hw/hw_$present_course/$timestamp"
			touch "$client_path/hw/hw_$present_course/$timestamp"
			printf "$hw_content" > "$client_path/hw/hw_$present_course/$timestamp"
			content_path="$client_path/hw/hw_$present_course/$timestamp"

			# 更新数据库中的作业要求信息
			$MYSQL -u$username -p$password homework <<EOF
delete from hw_$present_course where timestamp = '$timestamp';
insert into hw_$present_course values('$timestamp', '$hw_title', '$hw_type',  '$hw_issue_date', '$hw_due_date', '$content_path');
EOF
			# 显示是否成功的信息，并决定下一状态
			case $? in
				0) 
					zenity --info --width=150 --text  "修改成功" 2> >(grep -v GtkDialog >&2)
					on_state=26
				;;
				1) zenity --info --width=150 --text "修改失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		# 删除作业/实验
		29)
			# 弹窗提示是否确定要删除
			zenity --question --text "确定要删除该作业/实验吗？"

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=26
				continue
			fi

			# 从数据库中删除和本实验有关的数据
			$MYSQL -u$username -p$password homework <<EOF
delete from hw_${present_course} where timestamp = '$present_hw';
drop table ${present_course}_hw_$present_hw;
EOF
			# 显示是否成功的信息，并决定下一状态
			case $? in
				0) 
					zenity --info --width=150 --text  "删除成功" 2> >(grep -v GtkDialog >&2)
					on_state=26
				;;
				1) zenity --info --width=150 --text "删除失败" 2> >(grep -v GtkDialog >&2)
					on_state=26
				;;
			esac
		;;
		# 学生：选择要操作的课程列表
		30)
			# 从数据库中获得当前学生加入的课程，并进行格式化处理
			course_id=($($MYSQL -u$username -p$password homework -Bse "select ID from course where ID in (select course_id from stu_course where \
				student_id = '$username');"))
			course_name=($($MYSQL -u$username -p$password homework -Bse "select name from course where ID in (select course_id from stu_course where \
				student_id = '$username');"))
			course_list=()
			for(( i=0; i<${#course_id[@]}; i++ ))
			do
				course_list+=(FALSE "${course_id[$i]}" "${course_name[$i]}")
			done

			# 列表显示课程，并获得用户输入
			option=$(zenity --height=500 --width=400 --title="学生" --list --text "请选择要操作的课程" --radiolist  --column "选择" \
			--column "课号" --column "课程名" "${course_list[@]}")

			# 用户选择取消
			if [ $? == 1 ]; then
				exit 0
			fi

			# 用户没有选择课程
			if [ "$option" == "" ]; then
				zenity --info --width=150 --text "请选择要操作的课程" 2> >(grep -v GtkDialog >&2)
				continue
			# 设置用户选择的课程为当前课程，进入下一状态
			else
				present_course=$option
				on_state=31
			fi
		;;
		# 学生：列表显示功能选项
		31)
			# 列表显示可选功能，并读取用户输入
			option=$(zenity --height=400 --width=280 --title="学生" --list --text "当前课程：$present_course" --radiolist  --column "选择" \
			--column "功能" FALSE 查看课程公告 FALSE 查看作业与实验)

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=30
				continue
			fi

			# 根据用户输入决定下一状态
			case $option in
				"查看课程公告")
					on_state=32
				;;
				"查看作业与实验")
					on_state=34
				;;
			esac
		;;
		# 列表显示课程公告
		32)
			# 从数据库中读取课程公告信息，并作格式化处理
			title_all=$($MYSQL -u$username -p$password homework -Bse "select title from info_$present_course;")
			title_all=${title_all// /^^^}
			title=($title_all)

			date=($($MYSQL -u$username -p$password homework -Bse "select issue_date from info_$present_course;"))
			timestamp=($($MYSQL -u$username -p$password homework -Bse "select timestamp from info_$present_course;"))
			info_list=()
			for ((i=0; i<${#title[@]}; i++)); do
				info_list+=("${timestamp[$i]}" "${date[$i]}" "${title[$i]//^^^/ }")
			done

			# 列表显示课程公告
			info_selected=$(zenity --list --title="公告列表" --text="请选择要处理的课程信息/公告"\
			--height=600 --width=400 --column="编号" --column="日期" --column="标题" "${info_list[@]}")

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=31
				continue
			fi

			# 用户未选择要处理的课程信息
			if [ "$info_selected" == "" ]; then
				zenity --info --width=150 --text "请选择要处理的课程信息" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			# 设置用户选择的信息为当前信息，进入下一状态
			present_info=$info_selected
			on_state=33
		;;
		# 显示课程信息
		33)	
			# 窗口显示课程信息
			file="$($MYSQL -u$username -p$password homework -Bse "select content_path from info_$present_course where timestamp = '$present_info'")"
			title="$($MYSQL -u$username -p$password homework -Bse "select title from info_$present_course where timestamp = '$present_info'")"
			zenity --text-info --filename="$file" --title="$title"

			on_state=32
		;;
		# 列表显示本门课程作业与实验
		34)
			# 从数据库中读取当前课程作业和实验信息，并作格式化处理
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
				hw_state=$($MYSQL -u$username -p$password homework -Bse "select stu_id from ${present_course}_hw_${timestamp[$i]} where stu_id = '$username';" | wc -w)
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

			# 列表显示作业和实验，并读取用户选择
			hw_selected=$(zenity --list --title="作业与实验列表" --text="请选择要处理的作业或实验/公告"\
			--height=600 --width=600 --column="编号" --column="标题" --column="发布日期" --column="截止日期" --column="状态/得分" "${hw_list[@]}")

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=31
				continue
			fi

			# 用户未选择要处理的课程或实验
			if [ "$hw_selected" == "" ]; then
				zenity --info --width=150 --text "请选择要处理的课程或实验" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			# 设定用户选中的作业/实验为当前作业，并进入下一状态
			present_hw=$hw_selected
			on_state=35
		;;
		# 显示作业要求
		35)
			# 从数据库中读取作业信息，从文件中读取作业要求内容
			title="$($MYSQL -u$username -p$password homework -Bse "select title from hw_$present_course where timestamp='$present_hw';")"
			hw_path="$($MYSQL -u$username -p$password homework -Bse "select content_path from hw_$present_course where timestamp='$present_hw';")"
			type="$($MYSQL -u$username -p$password homework -Bse "select type from hw_$present_course where timestamp='$present_hw';")"
			issue_date="$($MYSQL -u$username -p$password homework -Bse "select issue_date from hw_$present_course where timestamp='$present_hw';")"
			due_date="$($MYSQL -u$username -p$password homework -Bse "select due_date from hw_$present_course where timestamp='$present_hw';")"

			# 窗口显示作业要求内容
			yad --center --width=400 --height=500 -margin=15 \
			--title="$title" --text="\n  类型：${type}\n\n  发布日期：${issue_date}\n\n  截止日期：${due_date}\n" \
			--text-info \
			--filename="$hw_path" \
			--button="返回":1\
			--button="提交作业":0

			# 根据用户点击的按钮决定下一状态
			case $? in
				0) on_state=36;;
				1) on_state=34;;
			esac
		;;
		# 选择作业提交方式
		36)
			# 列表显示作业提交方式，并读取用户选择
			selected=$(zenity --height=300 --width=280 --title="提交作业" --list --text "请选择作业提交方式" --radiolist  --column "选择" \
			--column "方式" FALSE "选取本地文件" FALSE "新建文件")
			
			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=35
				continue
			fi
			
			# 根据用户选择的提交方式决定下一状态
			case $selected in
				"选取本地文件")
					on_state=37
				;;
				"新建文件")
					on_state=38
				;;
			esac
		;;
		# 选取文件提交作业
		37)
			# 窗口选择待提交的作业
			file="$(zenity --height=600 --width=800 --file-selection --title="选择作业文件" --multiple --separator="^^^" 2> >(grep -v GtkDialog >&2))" 

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=36
				continue
			fi

			# 格式化处理作业文件列表
			file=${file// /!!!}
			file=${file//^^^/ }
			file_list=($file)

			# 之前曾经交过这个作业，目录存在，让用户选择是否保留上次作业
			if [ -d $client_path/hw/hw_$present_course/stu_$present_hw/$username ]; then
				zenity --question --text "是否保留上次提交的作业？" --ok-label="保留" --cancel-label="丢弃"
				# 删除上次提交的作业，并将本次提交的作业拷贝进作业目录
				if [ $? == 1 ]; then
					rm -r $client_path/hw/hw_$present_course/stu_$present_hw/$username
					mkdir $client_path/hw/hw_$present_course/stu_$present_hw/$username
					for(( i=0; i<${#file_list[@]}; i++ ))
					do
						filename=${file_list[i]//!!!/ }
						cp $filename $client_path/hw/hw_$present_course/stu_$present_hw/$username
					done
				# 保留原有文件。如果有重名文件则在文件名后面加编号
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
			# 第一次提交作业，建立文件夹并拷贝文件
			else
				mkdir $client_path/hw/hw_$present_course/stu_$present_hw/$username
				for(( i=0; i<${#file_list[@]}; i++ ))
				do
					filename=${file_list[i]//!!!/ }
					cp $filename $client_path/hw/hw_$present_course/stu_$present_hw/$username
				done
			fi

			# 在数据库中更新提交的作业信息
			$MYSQL -u$username -p$password homework <<EOF
delete from ${present_course}_hw_$timestamp where stu_id = '$username';
insert into ${present_course}_hw_$timestamp values('$username', '$client_path/hw/hw_$present_course/stu_$present_hw/$username', NULL);
EOF
			# 显示是否成功的信息，并决定下一状态
			case $? in
				0) 
					zenity --info --width=150 --text "提交成功" 2> >(grep -v GtkDialog >&2)
					on_state=35
				;;
				1) zenity --info --width=150 --text "提交失败" 2> >(grep -v GtkDialog >&2);;
			esac
		;;
		# 新建作业文件
		38)
			# 从窗口读取作业文件内容
			newhw="$(yad --center --width=400 --height=500 -margin=15 \
			--title="新建作业/实验" --text="请输入作业内容" \
			--form --date-format="%y-%m-%d" \
			--field="标题" \
			--field="内容":TXT )"

			# 用户选择取消
			if [ $? == 1 ]; then
				on_state=36
				continue
			fi

			# 之前曾提交过作业，上次提交的作业文件还存在
			if [ -d $client_path/hw/hw_$present_course/stu_$present_hw/$username ]; then
				# 询问是否保留之前的作业
				zenity --question --text "是否保留上次提交的作业？" --ok-label="保留" --cancel-label="丢弃"
				# 丢弃之前的作业，删除原有目录并建立新目录
				if [ $? == 1 ]; then
					rm -r $client_path/hw/hw_$present_course/stu_$present_hw/$username
					mkdir $client_path/hw/hw_$present_course/stu_$present_hw/$username
				fi
			# 第一次交作业，建立文件夹
			else
				mkdir $client_path/hw/hw_$present_course/stu_$present_hw/$username
			fi

			# 格式化处理从窗口读入的内容
			newhw="${newhw// /^^^}"
			newhw="${newhw//|/ }"
			newhw_item=($newhw)

			if [[ ${#newhw_item[@]} < 2 ]]; then
				zenity --info --width=150 --text "不允许有空栏" 2> >(grep -v GtkDialog >&2)
				continue
			fi

			hw_title="${newhw_item[0]//^^^/ }"
			hw_content="${newhw_item[1]//^^^/ }"

			# 若存在文件重名，则给文件增加编号
			if [ -e "$client_path/hw/hw_$present_course/stu_$present_hw/$username/$hw_title" ]; then
				declare -i num=0
				while [ -e "$client_path/hw/hw_$present_course/stu_$present_hw/$username/${hw_title}_$num" ]; do
					num=$num+1
				done
				hw_title=${hw_title}_$num
			fi

			# 创建新的作业文件，并将从窗口读入的内容输出到文件中
			touch $client_path/hw/hw_$present_course/stu_$present_hw/$username/$hw_title
			printf "$hw_content" > "$client_path/hw/hw_$present_course/stu_$present_hw/$username/$hw_title"

			# 在数据库中加入新提交作业的信息
			$MYSQL -u$username -p$password homework <<EOF
delete from ${present_course}_hw_$timestamp where stu_id = '$username';
insert into ${present_course}_hw_$timestamp values('$username', '$client_path/hw/hw_$present_course/stu_$present_hw/$username', NULL);
EOF
			
			# 显示是否成功的信息，并决定下一状态
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