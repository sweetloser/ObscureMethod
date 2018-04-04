#!/bin/sh


#获取脚本当前路径
shellPath=`dirname $0`

#获取配置文件(ObscureMethods.plist)的绝对路径
ConfigurationFilePath="${shellPath}/ObscureMethods.plist"


#获取类名（规范方法名：-(void)func:(int)s char:(char)c;）

function generateMethodNameFile()
{

	#遍历工程目录下所有的文件，找出.m和.h文件中的方法名，并重定向到文件中

	inputDir=$1
	methodNameFile=$2

	ObscureMethodsType=`/usr/libexec/PlistBuddy -c "print :ObscureMethodsType" "${ConfigurationFilePath}"`
	# ==== > 1.前缀匹配		2.文件夹筛选		3.方法排除		其他：error
	if [[ "${ObscureMethodsType}" == 1 ]]; then

		echo "有前缀设置"

		#获取plist文件中定义的方法名前缀
		PrefixString=`/usr/libexec/PlistBuddy -c "print :PrefixString" "${ConfigurationFilePath}"`

		echo "方法名前缀为：${PrefixString}"
		#带前缀方法名过滤
		grep -h -r "^[+-]" $inputDir --include "*.[mh]" | sed "/([ ]*IBAction[ ]*)/d" | sed "/(*^.*)/d" | sed "s/[ ]*{//g" | sed "s/[+-]//g" | sed "s/([^)]*)//g" | sed "s/;.*//g" | sed "s/[:,;{}]/ /g" | sed -n "/[ ]*${PrefixString}/p" | awk '{for(a=1;a<=NF;a++) if(a%2 == 1) print $a}' | sort | uniq >$methodNameFile
	
	elif [[ "${ObscureMethodsType}" == 2 ]]; then
		
		echo "文件夹筛选"
		# grep -H -r $inputDir --include "*.[mh]"  >$methodNameFile
		FilterDir=`/usr/libexec/PlistBuddy -c "print :FilterDirName" "${ConfigurationFilePath}"`

		echo "${FilterDir}"

		#过来文件夹
		grep -H -r "^[+-]" $inputDir --include "*.[mh]" | sed "/\/${FilterDir}\//d" | sed "/([ ]*IBAction[ ]*)/d" | sed "/(*^.*)/d" | sed "s/[ ]*{//g" | sed "s/;.*//g" | sed "s/([^)]*)//g" | sed "s/[:,;{}]/ /g" | sed "s/[+-]//g" | awk '{for(a=1;a<=NF;a++) if(a%2 == 0) print $a}' | sort | uniq >$methodNameFile


	elif [[ "${ObscureMethodsType}" == 3 ]]; then
		
		echo "方法排除"


		echo "没有前缀设置"
		
		#获取所有方法的tmp文件
		allMethodNameTmpFile="${shellPath}/allMethodNameTmpFile"

		#过滤方法的tmp文件
		filterMethodTmpFile="${shellPath}/filterMethodTmpFile"

		rm -rf "${allMethodNameTmpFile}" || true
		touch "${allMethodNameTmpFile}"

		rm -rf "${filterMethodTmpFile}" || true
		touch "${filterMethodTmpFile}"


		#			目标文件筛选.[mh] | 筛选【+-】开头的行	| 去除  【IBAction】 的行  	  |删除参数或者返回值带block的行|删除【;】后的所有字符|删除【{】和之前的空格|删除字符【+-】   | 删除(*)字符			|【:,;{}】==> [ ]	  | 通过【 】分割字符串，取到方法名						 | 排序  | 去重 > 重定向到文件
		grep -h -r "^[+-]" $inputDir --include "*.[mh]" | sed "/([ ]*IBAction[ ]*)/d" | sed "/(*^.*)/d" | sed "s/;.*//g" | sed "s/[ ]*{//g"| sed "s/[+-]//g" | sed "s/([^)]*)//g" | sed "s/[:,;{}]/ /g" | tr -d "\r" | awk '{for(a=1;a<=NF;a++) if(a%2 == 1) print $a}' | sort | uniq > allMethodNameTmpFile
		#没有设置方法名前缀过滤，则用`FilterMethods`数组过滤(默认过滤部分系统函数)

		/usr/libexec/PlistBuddy -c "print :FilterMethods" "${ConfigurationFilePath}" | sed -e '1d' -e '$d' | sed 's/ //g' | sort | uniq > $filterMethodTmpFile

		#在中`allMethodNameTmpFile` 过滤 配置文件中设置的方法
		comm -23 "${allMethodNameTmpFile}" "${filterMethodTmpFile}" | sort | uniq > ${methodNameFile}

		rm -rf "${allMethodNameTmpFile}"
		rm -rf "${filterMethodTmpFile}"

	else
		echo "ERROR"
		echo "请在plist配置文件中键入正确的筛选方式！\n"
		echo "key:ObscureMethodsType"
		echo "value（Number）:"
		echo "		1=====>方法名前缀筛选"
		echo "		2=====>文件夹筛选（指定文件夹不混淆）"
		echo "		3=====>特定方法名不混淆"
		echo "		其他==>错误"
	fi

	#筛选类名
	grep -h -r "^@implementation" $inputDir --include "*.[m]" | sed "s/[<:>()]/ /g" | sed "s/@implementation//g" | awk '{for(a=1;a<=NF;a++) if(a==1) print $a}' | sort | uniq >> $methodNameFile
	
}

#用openssl生成足够长的随机字符串
function generateRandString(){
	openssl rand -base64 256 | tr -c -d "a-zA-Z" | head -c 24
}

#生成头文件
#参数：
#$1:头文件路径
#$2:方法列表路径
function generateHeaderFile(){

	headerFile=$1

	methodlistfile=$2

	#获取文件名
	fileName=${headerFile##*/}

	#去除.h后缀
	nameWithouth=${fileName%.*}


	#头部define	
	#覆盖写入文件
	echo "#ifndef ${nameWithouth}_h" >${headerFile}
	#追加写入文件
	echo "#define ${nameWithouth}_h" >>${headerFile}

	cat ${methodlistfile} | while read line 
	do
		randstr=`generateRandString`

		if [[ "${SRCROOT}" ]]; then
			echo -e "#define\t\t${line}\t\t\t${randstr}" >>${headerFile}
		else
			echo "#define\t\t${line}\t\t\t${randstr}" >>${headerFile}

		fi

	done

	#endif
	echo "#endif /* ${nameWithouth}_h */" >>${headerFile}
	
}


function start(){
	path1=$1 #rootdirPath
	path2=$2 #funclistPath
	path3=$3 #ObscureMethodsPath

	generateMethodNameFile $path1 $path2

	generateHeaderFile $path3 $path2
}


#调用时输入两个参数
#$1:工程根目录	（默认为:${SRCROOT}/${PROJECT_NAME}）
#$2:方法列表文件路径	(默认为：${SRCROOT}/${PROJECT_NAME}/funclist)
#$3:define头文件目录	（默认为：${SRCROOT}/${PROJECT_NAME}/ObscureMethods.h）

rootdirPath=""
funclistPath=""
ObscureMethodsPath=""

if [[ "${SRCROOT}" && "${PROJECT_NAME}" ]]; then
	rootdirPath="${SRCROOT}/${PROJECT_NAME}"
fi



if [[ $# == 0 ]]; then
	echo "argc:0"
elif [[ $# == 1 ]]; then
	echo "argc:1"
	rootdirPath=$1
elif [[ $# == 2 ]]; then
	echo "argc:2"
	rootdirPath=$1
	funclistPath=$2
elif [[ $# == 3 ]]; then
	echo "argc:3"
	rootdirPath=$1
	funclistPath=$2
	ObscureMethodsPath=$3
fi

#判断根目录是否存在，如果不存在，直接退出
if [[ "${rootdirPath}" == "" && ! -d "${rootdirPath}" ]]; then
	echo "no dir"
	exit;
fi

if [[ "${funclistPath}" == "" ]]; then
	funclistPath="${rootdirPath}/funclist"
fi

if [[ "${ObscureMethodsPath}" == "" ]]; then
	ObscureMethodsPath="${rootdirPath}/ObscureMethods.h"
fi


#判断funclist文件和onscuremethod.h文件是否存在，如果不存在，则创建
if [[ ! -f "${funclistPath}" ]]; then
	
	touch "${funclistPath}"
fi

if [[ ! -f "ObscureMethodsPath" ]]; then
	touch "${ObscureMethodsPath}"
fi

start "${rootdirPath}" "${funclistPath}" "${ObscureMethodsPath}"

