#!/bin/sh

echo "=== aicomiter 功能测试 ==="
echo ""

# Test 1: 显示帮助
echo "Test 1: 显示帮助信息"
./aicomiter --help > /dev/null 2>&1 && echo "✓ 帮助显示正常"
echo ""

# Test 2: 生成命令帮助
echo "Test 2: 显示 generate 命令帮助"
./aicomiter generate --help > /dev/null 2>&1 && echo "✓ generate 帮助显示正常"
echo ""

# Test 3: 初始化配置
echo "Test 3: 初始化配置命令"
./aicomiter init --help > /dev/null 2>&1 && echo "✓ init 命令可用"
echo ""

# Test 4: 显示配置命令
echo "Test 4: 显示配置命令"
./aicomiter show-config --help > /dev/null 2>&1 && echo "✓ show-config 命令可用"
echo ""

# Test 5: 检查二进制大小
echo "Test 5: 检查二进制大小"
SIZE=$(ls -lh aicomiter | awk '{print $5}')
echo "二进制大小: $SIZE"
if [ $(echo "$SIZE" | sed 's/M//') -lt 10 ]; then
    echo "✓ 大小优化良好（< 10MB）"
fi
echo ""

# Test 6: 验证配置文件
echo "Test 6: 验证配置文件"
if [ -f ".aicomiter.yaml.example" ]; then
    echo "✓ 配置示例文件存在"
fi
echo ""

echo "=== 测试完成 ==="
