#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Control Points Viewer (PyQt5)
- 坐标系：左上角为原点，X 正向右，Y 正向下
- 左侧画布：按比例绘制每个 control point 的相对位置（随窗口缩放自适配）
- 右侧面板：显示每个点的 buff 与 buff 效果（效果描述来自 README）
- 顶部状态栏：显示连接状态与比赛分数/剩余时间（若接口可用）
- 数据来源：OpenRA_Copilot_Library GameAPI -> query_control_points / match_info_query / map_query

运行:
  python3 control_points_viewer.py --host localhost --port 7445

依赖:
  pip install PyQt5
"""

import sys
import os
import argparse
from typing import List, Dict, Any, Tuple, Optional

# 确保能 import OpenRA_Copilot_Library（兼容多种运行路径）
try:
    from OpenRA_Copilot_Library import GameAPI, GameAPIError
except Exception:
    this_dir = os.path.dirname(os.path.abspath(__file__))
    # 参考 tests/real_test.py 的插入方式，尽量兼容工程目录结构
    sys.path.insert(0, os.path.dirname(this_dir))
    sys.path.insert(0, os.path.dirname(os.path.dirname(this_dir)))
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(this_dir))))
    try:
        from OpenRA_Copilot_Library import GameAPI, GameAPIError
    except Exception as e:
        print("无法导入 OpenRA_Copilot_Library，请确认运行路径或调整 sys.path。错误：", e)
        sys.exit(1)

from PyQt5 import QtCore, QtGui, QtWidgets

# 从 README 整理的 buff 名称 -> 效果描述（中文）
BUFF_EFFECTS: Dict[str, str] = {
    # 通用 Buff（与 Lua GENERIC_BUFFS 保持一致）
    "cp_dmg_up_150": "火力大幅提升：攻击力 +150%",
    "cp_dmg_down_30": "火力骤降：攻击力 -70%",
    "cp_armor_30": "坚固：受到伤害系数 30%（-70%伤害）",
    "cp_armor_300": "极度脆弱：受到伤害系数 300%（+200%伤害）",

    # E1（步兵）
    "cp_inf_slow": "迟缓：移动速度 -80%，攻击速度 -80%",
    "cp_inf_berserk": "狂暴：攻击 +200%，移速 +100%，受伤 +200%",
    "cp_inf_accuracy": "精准：射程提升100%，攻击力提升200%",
    "cp_inf_overheat": "过热：装填 +100%，攻击 -50%",
    "cp_inf_fragile": "易伤：受到伤害 +300%",

    # RK（火箭兵）
    "cp_rkt_slow": "迟缓：移动速度 -80%，攻击速度 -80%",
    "cp_rkt_rapidfire": "连发：装填 -80%，攻击 -40%",
    "cp_rkt_overcharge": "过充：攻击 +400%，装填 +200%",
    "cp_rkt_anti_armor": "对装强化：攻击 +300%，射程 +20%",
    "cp_rkt_splash": "溅射增幅：攻击 +80%，射程 -20%",
    "cp_rkt_accuracy": "精准：射程提升100%，攻击力提升100%",
    "cp_rkt_malfunction": "故障：攻击 -70%，装填 +200%，射程 -50%",
    "cp_rkt_fragile": "易伤：受到伤害 +300%",

    # V2RL（V2 火箭）
    "cp_v2_rapidfire": "连发：装填 -80%，攻击 -20%",
    "cp_v2_range_decay": "射程衰减：射程 -60%，攻击 +150%",
    "cp_v2_overdrive": "过载：移速 +100%，攻击 +80%",
    "cp_v2_guidance_failure": "制导失效：攻击 -75%，射程 -60%，装填 +100%",
    "cp_v2_cant_move": "定身：移动速度 -90%",
    "cp_v2_fragile": "易伤：受到伤害 +300%",

    # FTRK（防空车）
    "cp_aa_rapidfire": "连发：装填 -75%，攻击 +50%",
    "cp_aa_overdrive": "过载：移速 +50%，攻击 +180%",
    "cp_aa_anti_ground": "对地强化：攻击 +150%，射程 +50%",
    "cp_aa_jammed": "受干扰：攻击 -80%，装填 +300%，射程 -70%",
    "cp_aa_fragile": "易伤：受到伤害 +300%",

    # 3TNK（三坦）
    "cp_tank_armor_up": "护甲强化：受到伤害 -90%",
    "cp_tank_slow": "迟缓：移动速度 -70%",
    "cp_tank_ap_rounds": "穿甲弹：攻击 +250%，射程 +20%",
    "cp_tank_engine_failure": "引擎故障：移速 -80%，攻击 -40%，受伤 +100%",
    "cp_tank_fragile": "易伤：受到伤害 +300%",
    "cp_tank_super_weak": "超级衰弱：攻击 -80%，受到伤害 +200%",

    # 4TNK（天启）
    "cp_mammoth_apex": "巅峰系统：攻击 +200%，移速 -20%，射程 +10%",
    "cp_mammoth_system_overload": "系统过载：攻击 -60%，移速 -85%，装填 +150%",
    "cp_mammoth_fragile": "极度易伤：受到伤害 +500%",
    "cp_mammoth_super_weak": "超级衰弱：攻击 -80%，受到伤害 +900%",

    # MIG
    # MIG 不在 README Buff 表展示，保持与规则一致（保留以兼容可能返回）
    "cp_mig_anti_armor": "对装/建筑强化：攻击 +150%，射程 +20%",
    "cp_mig_overdrive": "过载：移速 +50%，攻击 +40%",
    "cp_mig_maverick": "王牌：攻击 +200%，装填 -40%",
    "cp_mig_stall": "失速：移速 -70%，攻击 -60%，射程 -50%",
    "cp_mig_fragile": "易伤：受到伤害 +300%",

    # YAK
    "cp_yak_rapidfire": "连发：装填 -80%，攻击 -20%",
    "cp_yak_anti_infantry": "反步强化：攻击 +100%，移速 +20%",
    "cp_yak_chaingun": "链枪：攻击 +80%，装填 -70%",
    "cp_yak_jammed": "受干扰：攻击 -90%，移速 -90%，装填 +400%",
    "cp_yak_fragile": "易伤：受到伤害 +300%",
}


class ControlPointCanvas(QtWidgets.QWidget):
    hoverChanged = QtCore.pyqtSignal(object)  # 当前悬停的点数据

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMouseTracking(True)
        self.control_points: List[Dict[str, Any]] = []
        self.map_size: Tuple[int, int] = (256, 256)  # (width, height) 默认
        self.margins = 30
        self.point_radius = 8
        self._hover_index: Optional[int] = None

    def setData(self, control_points: List[Dict[str, Any]], map_size: Tuple[int, int]):
        self.control_points = control_points or []
        if map_size and map_size[0] > 0 and map_size[1] > 0:
            self.map_size = map_size
        self.update()

    def _coord_to_screen(self, x: int, y: int) -> QtCore.QPointF:
        W = max(1, self.map_size[0])
        H = max(1, self.map_size[1])
        w = max(1, self.width() - 2 * self.margins)
        h = max(1, self.height() - 2 * self.margins)
        sx = self.margins + (x / W) * w
        sy = self.margins + (y / H) * h
        return QtCore.QPointF(sx, sy)

    def paintEvent(self, event: QtGui.QPaintEvent) -> None:
        qp = QtGui.QPainter(self)
        qp.setRenderHint(QtGui.QPainter.Antialiasing, True)
        rect = self.rect()

        # 背景
        qp.fillRect(rect, QtGui.QColor(18, 18, 18))

        # 边框与绘图区域
        draw_rect = rect.adjusted(self.margins, self.margins, -self.margins, -self.margins)
        pen = QtGui.QPen(QtGui.QColor(80, 80, 80))
        pen.setWidth(1)
        qp.setPen(pen)
        qp.drawRect(draw_rect)

        # 画网格（简易）
        qp.setPen(QtGui.QPen(QtGui.QColor(45, 45, 45), 1, QtCore.Qt.DotLine))
        for i in range(1, 5):
            x = draw_rect.left() + i * draw_rect.width() / 5
            y = draw_rect.top() + i * draw_rect.height() / 5
            qp.drawLine(int(x), draw_rect.top(), int(x), draw_rect.bottom())
            qp.drawLine(draw_rect.left(), int(y), draw_rect.right(), int(y))

        # 画 control points
        font = QtGui.QFont("Arial", 10)
        qp.setFont(font)
        for idx, cp in enumerate(self.control_points):
            name = cp.get("name", f"CP{idx+1}")
            x = int(cp.get("x", 0))
            y = int(cp.get("y", 0))
            has_buffs = bool(cp.get("hasBuffs", False))
            buffs = cp.get("buffs", [])

            pt = self._coord_to_screen(x, y)
            # 点的颜色
            color = QtGui.QColor(76, 175, 80) if has_buffs else QtGui.QColor(120, 120, 120)
            if idx == self._hover_index:
                color = QtGui.QColor(255, 193, 7)  # 悬停高亮

            qp.setPen(QtCore.Qt.NoPen)
            qp.setBrush(QtGui.QBrush(color))
            qp.drawEllipse(pt, self.point_radius, self.point_radius)

            # 名称与坐标
            qp.setPen(QtGui.QPen(QtGui.QColor(220, 220, 220)))
            label = f"{name} ({x},{y})"
            qp.drawText(int(pt.x() + self.point_radius + 4), int(pt.y() - 6), label)

            # 简短 Buff 概览（只显示数量/标志）
            if buffs:
                qp.setPen(QtGui.QPen(QtGui.QColor(150, 200, 255)))
                qp.drawText(int(pt.x() + self.point_radius + 4), int(pt.y() + 12),
                            f"Buff x{len(buffs)}")

    def mouseMoveEvent(self, event: QtGui.QMouseEvent) -> None:
        pos = event.pos()
        hover_idx = None
        hover_data = None

        # 选择最近且在半径范围内的点
        min_d2 = (self.point_radius + 4) ** 2
        for idx, cp in enumerate(self.control_points):
            pt = self._coord_to_screen(int(cp.get("x", 0)), int(cp.get("y", 0)))
            dx = pos.x() - pt.x()
            dy = pos.y() - pt.y()
            d2 = dx * dx + dy * dy
            if d2 <= min_d2:
                hover_idx = idx
                hover_data = cp
                break

        if hover_idx != self._hover_index:
            self._hover_index = hover_idx
            self.update()
            self.hoverChanged.emit(hover_data)

        super().mouseMoveEvent(event)


class ControlPointsViewer(QtWidgets.QMainWindow):
    def __init__(self, host: str, port: int, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Control Points Viewer")
        self.resize(1100, 700)

        # API
        self.host = host
        self.port = port
        self.api: Optional[GameAPI] = None
        self.connected: bool = False

        # UI
        self.canvas = ControlPointCanvas()
        self.tree = QtWidgets.QTreeWidget()
        self.tree.setHeaderLabels(["据点/BUFF", "效果"])
        self.tree.header().setSectionResizeMode(0, QtWidgets.QHeaderView.ResizeToContents)
        self.tree.header().setSectionResizeMode(1, QtWidgets.QHeaderView.Stretch)
        self.tree.setAlternatingRowColors(True)
        self.tree.setRootIsDecorated(True)

        splitter = QtWidgets.QSplitter()
        splitter.addWidget(self.canvas)
        splitter.addWidget(self.tree)
        splitter.setStretchFactor(0, 2)
        splitter.setStretchFactor(1, 1)
        self.setCentralWidget(splitter)

        # 状态栏
        self.status = self.statusBar()
        self.conn_label = QtWidgets.QLabel("连接: 未连接")
        self.match_label = QtWidgets.QLabel("比赛: -")
        self.status.addPermanentWidget(self.conn_label)
        self.status.addPermanentWidget(self.match_label)

        # 悬停提示
        self.canvas.hoverChanged.connect(self.onHoverChanged)

        # 定时器：拉取数据
        self.timer = QtCore.QTimer(self)
        self.timer.setInterval(1000)  # 1s
        self.timer.timeout.connect(self.refreshData)

        # 定时器：连接检测与自动重连
        self.conn_timer = QtCore.QTimer(self)
        self.conn_timer.setInterval(1000)  # 1s
        self.conn_timer.timeout.connect(self.check_connection_and_reconnect)

        # 初始化
        self.init_api_and_start()

    def init_api_and_start(self):
        try:
            # 初始尝试连接
            is_up = GameAPI.is_server_running(self.host, self.port, 1.0)
            if is_up:
                self.api = GameAPI(self.host, self.port, "zh")
                self.connected = True
            else:
                self.connected = False
            self.update_connection_label()
            # 启动两个定时器：连接监控 & 数据刷新
            self.conn_timer.start()
            self.timer.start()
        except Exception as e:
            self.connected = False
            self.update_connection_label(error=str(e))

    def update_connection_label(self, error: Optional[str] = None):
        if self.connected:
            dot = '<span style="color:#4caf50; font-weight:bold;">●</span>'
            self.conn_label.setText(f"{dot} 已连接 {self.host}:{self.port}")
        else:
            dot = '<span style="color:#f44336; font-weight:bold;">●</span>'
            if error:
                self.conn_label.setText(f"{dot} 未连接（{error}）")
            else:
                self.conn_label.setText(f"{dot} 未连接 {self.host}:{self.port}")

    def check_connection_and_reconnect(self):
        """每秒检测当前是否连接；未连接则尝试重连。参考 tests/real_test.py 的连接检测实现。"""
        try:
            is_up = GameAPI.is_server_running(self.host, self.port, 1.0)
        except Exception:
            is_up = False

        if is_up:
            if not self.connected:
                # 刚恢复：构造 API 实例
                try:
                    self.api = GameAPI(self.host, self.port, "zh")
                    self.connected = True
                except Exception as e:
                    self.connected = False
                    self.update_connection_label(error=str(e))
                    return
            # 已连接或刚连接成功
            self.update_connection_label()
        else:
            # 断开
            self.connected = False
            self.update_connection_label()

    def refreshData(self):
        # 先确保连接状态
        if not self.connected or self.api is None:
            # 未连接时不拉取数据
            self.match_label.setText("比赛: -")
            return

        # 地图尺寸
        map_size = (256, 256)
        try:
            m = self.api.map_query()
            if m and getattr(m, "MapWidth", 0) > 0 and getattr(m, "MapHeight", 0) > 0:
                map_size = (int(m.MapWidth), int(m.MapHeight))
        except Exception:
            pass

        # 控制点
        control_points = []
        try:
            cp_res = self.api.control_point_query()
            # cp_res.ControlPoints 由库封装；也兼容 dict 形式
            raw_list = []
            if hasattr(cp_res, "ControlPoints"):
                raw_list = getattr(cp_res, "ControlPoints") or []
            elif isinstance(cp_res, dict):
                raw_list = cp_res.get("controlPoints", []) or []

            # 规范化
            for item in raw_list:
                control_points.append({
                    "name": item.get("name", "Unknown"),
                    "x": int(item.get("x", 0)),
                    "y": int(item.get("y", 0)),
                    "hasBuffs": bool(item.get("hasBuffs", False)),
                    "buffs": item.get("buffs", []),
                })

            # 更新画布
            self.canvas.setData(control_points, map_size)
            # 更新右侧树
            self.populateTree(control_points)

        except GameAPIError as e:
            self.status.showMessage(f"查询控制点失败: {e.code} - {e.message}", 2000)
        except Exception as e:
            self.status.showMessage(f"查询控制点异常: {e}", 2000)

        # 比赛信息
        try:
            match = self.api.match_info_query()
            if match:
                self_score = getattr(match, "SelfScore", 0) or getattr(match, "selfScore", 0)
                enemy_score = getattr(match, "EnemyScore", 0) or getattr(match, "enemyScore", 0)
                remaining_time = getattr(match, "RemainingTime", None) or getattr(match, "remainingTime", None)
                self.match_label.setText(f"比赛: 我方 {self_score} - 敌方 {enemy_score}  | 剩余: {remaining_time}")
        except Exception:
            pass

    def populateTree(self, control_points: List[Dict[str, Any]]):
        self.tree.clear()
        for cp in control_points:
            root = QtWidgets.QTreeWidgetItem(self.tree)
            root.setText(0, f"{cp.get('name', 'Unknown')}  ({cp.get('x', 0)},{cp.get('y', 0)})")
            root.setFirstColumnSpanned(False)

            buffs: List[Dict[str, Any]] = cp.get("buffs", [])
            if not buffs:
                child = QtWidgets.QTreeWidgetItem(root)
                child.setText(0, "无 Buff")
                child.setText(1, "-")
                continue

            for b in buffs:
                unit_type = b.get("unitType", "")
                buff_name = b.get("buffName", "")
                effect = BUFF_EFFECTS.get(buff_name, "（无对应效果描述，查看 README 或规则）")
                child = QtWidgets.QTreeWidgetItem(root)
                child.setText(0, f"{buff_name}")
                # 显示时：兵种在最前面，不显示 buffType
                child.setText(1, f"单位:{unit_type}  |  {effect}")

        self.tree.expandAll()

    def onHoverChanged(self, cp: Optional[Dict[str, Any]]):
        if not cp:
            QtWidgets.QToolTip.hideText()
            return

        name = cp.get("name", "Unknown")
        x = cp.get("x", 0)
        y = cp.get("y", 0)
        lines = [f"<b>{name}</b>  ({x},{y})"]
        buffs = cp.get("buffs", [])
        if not buffs:
            lines.append("无 Buff")
        else:
            for b in buffs:
                bn = b.get("buffName", "")
                effect = BUFF_EFFECTS.get(bn, "（无对应效果描述）")
                ut = b.get("unitType", "")
                # 悬停提示：兵种在最前，不显示 buffType
                lines.append(f"单位:{ut} | {bn}：{effect}")

        QtWidgets.QToolTip.showText(QtGui.QCursor.pos(), "<br/>".join(lines), self)

def parse_args():
    p = argparse.ArgumentParser(description="Control Points Viewer (PyQt5)")
    p.add_argument("--host", type=str, default="localhost", help="游戏服务器地址")
    p.add_argument("--port", type=int, default=7445, help="游戏服务器端口")
    return p.parse_args()

def main():
    args = parse_args()
    app = QtWidgets.QApplication(sys.argv)
    win = ControlPointsViewer(args.host, args.port)
    win.show()
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()