#!/bin/bash

# 默认参数值
mod="Game.Mod=copilot"
loadsave="Game.LoadSave=None"
port="Game.CopilotPort=7445"
debug="Game.CopilotDebug=True"

# 标记参数是否已提供
has_mod=false
has_loadsave=false
has_port=false
has_debug=false
has_is_agent_mode=false

# 其他参数收集
other_args=()

# 遍历传入参数
for arg in "$@"; do
  case "$arg" in
    Game.Mod=*) mod="$arg"; has_mod=true ;;
    Game.LoadSave=*) loadsave="$arg"; has_loadsave=true ;;
    Game.CopilotPort=*) port="$arg"; has_port=true ;;
    Game.CopilotDebug=*) debug="$arg"; has_debug=true ;;
    Game.IsAgentMode=*) is_agent_mode="$arg"; has_is_agent_mode=true ;;
    *) other_args+=("$arg") ;;
  esac
done

# 组装命令行
cmd="./launch-game.sh $mod $loadsave $port $debug $is_agent_mode"
for arg in "${other_args[@]}"; do
  cmd="$cmd $arg"
done

# 输出并执行
echo "$cmd"
eval "$cmd"