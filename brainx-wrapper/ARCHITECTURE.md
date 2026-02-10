# BrainX V2 Multi-Agent Architecture

## Resumen

Sistema de memoria compartida para múltiples agentes OpenClaw usando BrainX V2 como backend centralizado.

```
┌─────────────────────────────────────────────────────────────────────┐
│                      BRAINX V2 CENTRAL                              │
│                  PostgreSQL / Storage Backend                        │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  DECISIONS │ ACTIONS │ LEARNINGS │ GOTCHAS │ SESSIONS       │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              ↓                   ↓                   ↓
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│  @coder       │     │  @writer      │     │ @researcher   │
│ brainx-wrapper│     │ brainx-wrapper│     │ brainx-wrapper│
│ workspace-coder│     │ workspace-writer│   │ workspace-re..│
└───────────────┘     └───────────────┘     └───────────────┘
```

## Componentes

### 1. Wrapper por Workspace

Cada workspace tiene su propia copia de `brainx-wrapper/`:

```
workspace-<agent>/
├── brainx-wrapper/
│   ├── agent-wrapper      ← Script principal (source esto)
│   ├── config.sh          ← Config específica del agent
│   └── logs/
│       └── wrapper.log
├── AGENTS.md
├── SOUL.md
└── ... (otros archivos del workspace)
```

### 2. Configuración Centralizada

```bash
# brainx-wrapper/config.sh (por workspace)

# Identidad
BRAINX_AGENT_ID="coder"        #唯一标识符
BRAINX_AGENT_NAME="@coder"     #带 @ 的名称
BRAINX_WORKSPACE="workspace-coder"

# 连接
BRAINX_HOME="/home/clawd/.openclaw/workspace/skills/brainx-v2"
BRAINX_DB="postgresql://brainx:pass@localhost:5432/brainx_v2"

# 特性
BRAINX_CENTRAL_ENABLED=true
CLUSTER_NAME="openclaw-prod"
```

### 3. Deployment Script

```bash
# 从 workspace-clawma 运行
cd /home/clawd/.openclaw/workspace-clawma
./brainx-wrapper/deploy-brainx-multiagent.sh --force
```

## 使用

### 基础使用

```bash
# 在 workspace 中 source wrapper
source /home/clawd/.openclaw/workspace-coder/brainx-wrapper/agent-wrapper

# 开始会话
session_start "implementando API de usuarios"

# 记录决策
session_decision "Usar JWT para autenticación" "Stateless y estándar" 8

# 记录动作
session_action "Creé endpoint POST /users" "completado" "api,users"

# 记录学习
session_learning "pattern: validación" "Validar input en el boundary" "api"

# 结束会话
session_end "API de usuarios completada"
```

### 跨 Agent 通信

```bash
# 发送消息给另一个 agent
agent_send "writer" "Necesito documentación para la API de usuarios"

# 广播给所有 agents
agent_broadcast "Nueva versión de BrainX desplegada"
```

### 上下文注入

```bash
# 获取相关上下文
CONTEXTO=$(inject_context "cómo implementé la autenticación JWT")

# 在命令中使用
run_with_context "autenticación JWT" "$MI_COMANDO"
```

## Agent 列表

| Agent ID | Workspace | 状态 | 备注 |
|----------|-----------|------|------|
| clawma | workspace-clawma | ✅ | 主 agent |
| coder | workspace-coder | ⏳ | 待部署 |
| main | workspace-main | ⏳ | 待部署 |
| writer | workspace-writer | ⏳ | 待部署 |
| researcher | workspace-researcher | ⏳ | 待部署 |
| reasoning | workspace-reasoning | ⏳ | 待部署 |
| support | workspace-support | ⏳ | 待部署 |
| projects | workspace-projects | ⏳ | 待部署 |

## 数据流

```
1. Agent 执行 action
   ↓
2. Wrapper 记录到本地 log
   ↓
3. Wrapper 调用 brainx hook
   ↓
4. BrainX Central 持久化
   ↓
5. 其他 Agent 可查询
```

## 文件结构

```
/home/clawd/.openclaw/
├── workspace-clawma/
│   └── brainx-wrapper/
│       ├── agent-wrapper          ← 主脚本
│       ├── deploy-brainx-multiagent.sh ← 部署脚本
│       ├── config.sh              ← Clawma 配置
│       ├── integrate-with-openclaw.md
│       └── logs/
│           └── wrapper.log
├── workspace-coder/
│   └── brainx-wrapper/             ← 部署后生成
│       ├── agent-wrapper
│       ├── config.sh
│       └── logs/
├── workspace-*/
│   └── brainx-wrapper/             ← 每个 agent
│       ...
├── workspace/skills/
│   └── brainx-v2/                  ← BrainX V2 CLI
└── .brainx-agents-registry         ← Agent 注册表
```

## 注意事项

1. **BrainX V2 必须安装在**: `/home/clawd/.openclaw/workspace/skills/brainx-v2/`
2. **每个 workspace 独立日志**: `brainx-wrapper/logs/wrapper.log`
3. **Agent ID 自动检测**: 从 workspace 路径推断
4. **Central DB 建议**: PostgreSQL para 生产环境

## 故障排除

```bash
# 检查某个 agent 的状态
source /home/clawd/.openclaw/workspace-coder/brainx-wrapper/agent-wrapper
health_check

# 查看日志
tail -f /home/clawd/.openclaw/workspace-coder/brainx-wrapper/logs/wrapper.log

# 检查注册表
cat /home/clawd/.openclaw/.brainx-agents-registry
```

## 下一步

- [ ] 安装 BrainX V2 CLI
- [ ] 配置 PostgreSQL 数据库
- [ ] 运行部署脚本
- [ ] 验证每个 agent 的 health check
- [ ] 测试跨 agent 通信
