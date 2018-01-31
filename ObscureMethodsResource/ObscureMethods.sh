#!/bin/sh


ConfigurationFilePath="./ObscureMethods.plist"


#获取类名（规范方法名：-(void)func:(int)s char:(char)c;）

function generateMethodNameFile(){

	#遍历工程目录下所有的文件，找出.m和.h文件中的方法名，并重定向到文件中

	inputDir=$1
	methodNameFile=$2

	ObscureMethodsPrefix=`/usr/libexec/PlistBuddy -c "print:ObscureMethodsPrefix" "${ConfigurationFilePath}"`
	if [[ "${ObscureMethodsPrefix}" == true ]]; then

		#获取plist文件中定义的方法名前缀
		PrefixString=`/usr/libexec/PlistBuddy -c "print:PrefixString" "${ConfigurationFilePath}"`

		#带前缀方法名过滤
		grep -h -r "^[+-]" $inputDir --include "*.[mh]" | sed "/([ ]*IBAction[ ]*)/d" | sed "s/[+-]//g" | sed "s/([^)]*)//g" | sed "s/[:,;{}]/ /g" | sed -n "/[ ]*${PrefixString}/p" | awk '{for(a=1;a<=NF;a++) if(a%2 == 1) print $a}' | sort | uniq >$methodNameFile
	
	else
		
		allMethodNameTmpFile="./allMethodNameTmpFile"
		filterMethodTmpFile="./filterMethodTmpFile"

		rm -rf "${allMethodNameTmpFile}" || true
		touch "${allMethodNameTmpFile}"

		rm -rf "${filterMethodTmpFile}" || true
		touch "${filterMethodTmpFile}"

		grep -h -r "^[+-]" $inputDir --include "*.[mh]" | sed "/([ ]*IBAction[ ]*)/d" | sed "s/[+-]//g" | sed "s/([^)]*)//g" | sed "s/[:,;{}]/ /g" | awk '{for(a=1;a<=NF;a++) if(a%2 == 1) print $a}' | sort | uniq >$allMethodNameTmpFile


		#没有设置方法名前缀过滤，则用`FilterMethods`数组过滤(默认过滤部分系统函数)
		/usr/libexec/PlistBuddy -c "print:FilterMethods" "${ConfigurationFilePath}" | sed -e '1d' -e '$d' | sed 's/ //g' | sort | uniq > $filterMethodTmpFile

		comm -23 "${allMethodNameTmpFile}" "${filterMethodTmpFile}" | sort | uniq > ${methodNameFile}

		rm -rf "${allMethodNameTmpFile}"
		rm -rf "${filterMethodTmpFile}"
	fi
}

#用openssl生成足够长的随机字符串
function generateRandString(){
	openssl rand -base64 256 | tr -c -d "a-zA-Z" #| head -c 16
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
	echo "args:0"
elif [[ $# == 1 ]]; then
	echo "args:1"
	rootdirPath=$1
elif [[ $# == 2 ]]; then
	echo "args:2"
	rootdirPath=$1
	funclistPath=$2
elif [[ $# == 3 ]]; then
	echo "args:3"
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

