#!/bin/sh

# list of un check command
unchecked_cmds="readlink ps tar ssh scp ldd awk "
uninstall_cmds=""
so_list=""
check_cmd_avaible() {
    if ! command -v $1 >/dev/null 2>&1;then
        return 1
    fi
    return 0
}

print_usage() {
    echo "Usage: $0 <pid>"
}

# check paramareter equal to 2
if [ $# -ne 1 ]; then
    print_usage
    exit 1
fi

pid=$1
tar_path="/tmp/$pid.tar.gz"
tar_dir="/tmp/$pid"

# test /tmp/pid directory exists, if not then mkdir
if [ ! -d $tar_dir ]; then
    mkdir /tmp/$pid
fi

# test /tmp/pid.tar.gz exists, if exists then delete it
if [ -f $tar_path ]; then
    rm /tmp/$pid.tar.gz
fi

# check if the pid is a number
echo $pid | grep -q -E '^[0-9]\+$'
if [ $? -eq 0 ]; then
    echo "Error: $pid is not a number"
    print_usage
    exit 1
fi

# check if the pid is a valid process
if ! ps -p $pid >/dev/null; then
    echo "Error: $pid is not a valid process"
    print_usage
    exit 1
fi

# 确认命令存在
for cmd in $unchecked_cmds; do
    check_cmd_avaible $cmd
    if [ $? -ne 0 ]; then
        uninstall_cmds="$uninstall_cmds $cmd"
    fi
done

#如果有命令不存在则打印并退出
if test "x$uninstall_cmds" != "x"; then
    echo "Error: $uninstall_cmds is not installed"
    exit 1
fi

# 获取到路径 test /proc/$pid/exe exists
if [ ! -f /proc/$pid/exe ]; then
    echo "Error: /proc/$pid/exe does not exist"
    # todo 根据命令行在系统某些目录上查找
    exit 1
fi
exe=$(readlink /proc/$pid/exe)

echo "begin collect $exe loaded so to $tar_path"


# use ldd to get the shared object
ldd_so=$(ldd $exe)
echo "$ldd_so" | while read -r so; do
    ldd_path=$(echo $so | awk '{print $3}')
    if test "x$ldd_path" != "x"; then
        so_path=$(readlink -f $(echo $so | awk '{print $3}'))
        echo "copy $so_path to $tar_dir"
        # test so_path exists
        if [ ! -f $so_path ]; then
            echo "Error: $so_path does not exist"
            continue
        fi
        if [ -f $tar_dir/$(basename $so_path) ]; then
            continue
        fi
        cp $so_path $tar_dir
    else
        so_path=$(readlink -f $(echo $so | awk '{print $1}'))
        if [ ! -f $so_path ]; then
            echo "Error: $so_path does not exist"
            continue
        fi
        if [ -f $tar_dir/$(basename $so_path) ]; then
            continue
        fi
        echo "copy $so_path to $tar_dir"
        cp $so_path $tar_dir
    fi
done
# printf "%s\n" "$ldd_so"
echo "---------------------------------------------------"
map_path=""
# test /proc/$pid/maps exists
if [ ! -f /proc/$pid/maps ]; then
    # test /proc/$pid/map exists
    if [ ! -f /proc/$pid/map ]; then
        echo "Error: /proc/$pid/map does not exist"
        exit 1
    else
        map_path="/proc/$pid/map"
    fi
else
    map_path="/proc/$pid/maps"
fi

# test map_path not empty
if [ -z $map_path ]; then
    echo "Error: map_path is empty"
    exit 1
fi
cat $map_path | grep -o '/.*\.so.*' | sort | uniq | while read -r so; do
    so_path=$(readlink -f $so)
    #test so_path exists in /tmp/$pid
    if [ -f $tar_dir/$(basename $so_path) ]; then
        echo "$(basename $so_path) exists in $tar_dir"
        continue
    fi
    echo "copy $so_path to $tar_dir"
    cp $so_path $tar_dir
done


tar -czvf $tar_path $tar_dir >/dev/null 2>&1
# test tar_path exists
if [ ! -f $tar_path ]; then
    echo "Error: $tar_path does not exist"
    exit 1
fi
 echo "process $pid loaded so has been collected to $tar_path"
