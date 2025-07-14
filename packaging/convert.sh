#!/bin/bash

# 使用 find 遍历当前目录及子目录中的所有 .sh 文件
find . -type f -name "*.sh" | while read file; do
    # 转换 Windows 风格换行符到 Unix 风格换行符
    sed -i 's/\r$//' "$file"
    echo "Converted: $file"
done

echo "All .sh files in the current directory and subdirectories have been converted."
