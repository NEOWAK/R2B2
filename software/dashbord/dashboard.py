import math
import random
import time
import tkinter as tk
from dataclasses import dataclass, field
from typing import Dict, Optional

MAC_BLE_ROBOT = "AA:BB:CC:DD:EE:FF"
WINDOW_W = 1400
WINDOW_H = 900
REFRESH_MS = 120
SPLIT_RATIO = 0.25
ROBOT_SIZE_M = 0.25
COURT_LENGTH_M = 23.77
COURT_WIDTH_M = 10.97
SINGLES_WIDTH_M = 8.23
SERVICE_LINE_DIST_M = 6.40
NET_Y_M = COURT_LENGTH_M / 2

ULTRASONIC_SENSORS = [
    {"name": "front_left_corner",  "angle_deg": -45},
    {"name": "front",              "angle_deg":   0},
    {"name": "front_right_corner", "angle_deg":  45},
    {"name": "right",              "angle_deg":  90},
    {"name": "rear_right_corner",  "angle_deg": 135},
    {"name": "rear",               "angle_deg": 180},
    {"name": "rear_left_corner",   "angle_deg": 225},
    {"name": "left",               "angle_deg": 270},
]

external_get_parameters = None
try:
    from ble_robot import get_parameters as external_get_parameters
except Exception:
    pass


@dataclass
class RobotState:
    x_m: float = COURT_WIDTH_M / 2
    y_m: float = COURT_LENGTH_M * 0.75
    heading_deg: float = 0.0
    vx_mps: float = 0.0
    vy_mps: float = 0.0
    battery_pct: float = 100.0
    balls_stored: int = 0
    sensor_distances_m: Dict[str, float] = field(default_factory=dict)
    timestamp: float = field(default_factory=time.time)
    connection_ok: bool = True
    source_label: str = "BLE"


class DemoDataSource:
    def __init__(self):
        self.t0 = time.time()

    def get_parameters(self, mac):
        t = time.time() - self.t0
        sensors = {}
        heading = (t * 38.0) % 360
        for s in ULTRASONIC_SENSORS:
            a = math.radians(s["angle_deg"] + heading)
            base = 2.7 + 2.2 * (0.5 + 0.5 * math.sin(t * 0.7 + a))
            sensors[s["name"]] = max(0.25, min(5.5, base + random.uniform(-0.18, 0.18)))
        return {
            "x_m": COURT_WIDTH_M / 2 + 2.2 * math.sin(t / 4.2),
            "y_m": COURT_LENGTH_M * 0.70 + 6.0 * math.sin(t / 7.0),
            "heading_deg": heading,
            "vx_mps": 0.55 * math.cos(t / 4.2),
            "vy_mps": 0.86 * math.cos(t / 7.0),
            "battery_pct": max(15.0, 100.0 - t * 0.03),
            "balls_stored": int((t / 8.5) % 12),
            "sensor_distances_m": sensors,
        }


class DataAdapter:
    def __init__(self, mac):
        self.mac  = mac
        self.demo = DemoDataSource()

    def _normalize(self, raw) -> RobotState:
        sd = raw.get("sensor_distances_m") or {}
        normalized = {}
        for s in ULTRASONIC_SENSORS:
            try:    normalized[s["name"]] = float(sd.get(s["name"], 5.0))
            except: normalized[s["name"]] = 5.0
        state = RobotState(
            x_m=float(raw.get("x_m", COURT_WIDTH_M / 2)),
            y_m=float(raw.get("y_m", COURT_LENGTH_M / 2)),
            heading_deg=float(raw.get("heading_deg", 0.0)),
            vx_mps=float(raw.get("vx_mps", 0.0)),
            vy_mps=float(raw.get("vy_mps", 0.0)),
            battery_pct=float(raw.get("battery_pct", 100.0)),
            balls_stored=int(raw.get("balls_stored", 0)),
            sensor_distances_m=normalized,
            source_label="BLE" if external_get_parameters else "DEMO",
        )
        state.x_m = max(0.0, min(COURT_WIDTH_M,  state.x_m))
        state.y_m = max(0.0, min(COURT_LENGTH_M, state.y_m))
        state.battery_pct = max(0.0, min(100.0, state.battery_pct))
        return state

    def get_state(self) -> RobotState:
        try:
            raw = (external_get_parameters or self.demo.get_parameters)(self.mac)
            return self._normalize(raw)
        except Exception:
            state = self._normalize(self.demo.get_parameters(self.mac))
            state.connection_ok = False
            state.source_label  = "DEMO (fallback)"
            return state


class TennisRobotUI:
    DIVIDER_W  = 4
    TELEMETRY_H = 190   # hauteur fixe du panneau télémétrie

    def __init__(self, root, adapter):
        self.root    = root
        self.adapter = adapter
        self.root.title("Tennis Robot Monitor")
        self.root.geometry(f"{WINDOW_W}x{WINDOW_H}")
        self.root.minsize(900, 600)
        self.root.configure(bg="#101417")

        self.state   = RobotState(sensor_distances_m={s["name"]: 5.0 for s in ULTRASONIC_SENSORS})
        self.running = True
        # Occupancy map 2D à résolution 5 cm
        # Dimensions : terrain + 1 m de marge de chaque côté
        self.MAP_RES   = 0.05   # mètres par cellule
        self.MAP_MARGIN = 1.0   # marge autour du terrain
        self._map_cols = int((COURT_WIDTH_M  + 2*self.MAP_MARGIN) / self.MAP_RES) + 1
        self._map_rows = int((COURT_LENGTH_M + 2*self.MAP_MARGIN) / self.MAP_RES) + 1
        # Valeurs : -1 = inconnu, sinon distance minimale de détection en mètres
        self._occ_map  = [[-1.0]*self._map_cols for _ in range(self._map_rows)]
        # Trajet robot
        self._robot_trail = []

        self.canvas = tk.Canvas(self.root, bg="#0f1418", highlightthickness=0)
        self.canvas.pack(fill="both", expand=True)
        self.canvas.bind("<Configure>", lambda _: self.redraw())
        self._refresh_loop()

    def _refresh_loop(self):
        if not self.running:
            return
        self.state = self.adapter.get_state()
        speed = math.hypot(self.state.vx_mps, self.state.vy_mps)
        self.root.title("Tennis Robot Monitor")
        self._update_map()
        self.redraw()
        self.root.after(REFRESH_MS, self._refresh_loop)

    def redraw(self):
        c = self.canvas
        c.delete("all")
        W = c.winfo_width()
        H = c.winfo_height()
        if W < 20 or H < 20:
            return

        split = int(W * SPLIT_RATIO)
        c.create_rectangle(0, 0, W, H, fill="#101417", outline="")

        self._draw_left(c, 0, 0, split, H)

        # Séparateur
        c.create_rectangle(split, 0, split + self.DIVIDER_W, H, fill="#2c3e50", outline="")

        self._draw_court_view(c, split + self.DIVIDER_W, 0, W - split - self.DIVIDER_W, H)

    # ------------------------------------------------------------------
    # Partie gauche
    # ------------------------------------------------------------------
    def _draw_left(self, c, x, y, w, h):
        telem_h = int(h * 0.40)
        # --- Télémétrie pleine largeur en haut ---
        self._draw_telemetry_panel(c, x, y, w, telem_h)

        # --- Vue locale robot en dessous ---
        ry = y + telem_h
        rh = h - telem_h
        self._draw_robot_view(c, x, ry, w, rh)

    # ------------------------------------------------------------------
    # Panneau télémétrie (pleine largeur)
    # ------------------------------------------------------------------
    def _draw_telemetry_panel(self, c, x, y, w, h):
        speed = math.hypot(self.state.vx_mps, self.state.vy_mps)
        PAD   = 10
        cx    = x + w / 2

        c.create_rectangle(x, y, x + w, y + h, fill="#0b1014", outline="")

        # Titre
        TITLE_H = 26

        # Dégradé titre : #1a3a50 (haut) -> #0b1014 (bas)
        r1,g1,b1 = 0x1a,0x3a,0x50
        r2,g2,b2 = 0x0b,0x10,0x14
        for i in range(TITLE_H):
            t = i / max(1, TITLE_H - 1)
            r = int(r1 + (r2-r1)*t)
            g = int(g1 + (g2-g1)*t)
            b = int(b1 + (b2-b1)*t)
            c.create_line(x, y+i, x+w, y+i, fill=f"#{r:02x}{g:02x}{b:02x}")

        c.create_text(x + w / 2, y + TITLE_H / 2, anchor="center",
                      text="Télémétrie", fill="#7ec8e3", font=("Helvetica", 10, "bold"))

        uy = y + TITLE_H
        uh = h - TITLE_H

        # Définition des zones : (fraction début, fraction fin)
        zones = [
            (0.00, 0.30),   # Rangée 1 : pos
            (0.30, 0.57),   # Rangée 2 : vitesse / cap
            (0.57, 0.85),   # Rangée 3 : balles / batterie
            (0.85, 1.00),   # Rangée 4 : source
        ]

        col_w = (w - PAD * 3) / 2
        lx    = x + PAD
        rx    = lx + col_w + PAD

        # ── Rangée 1 : Pos X | Pos Y ──
        z = zones[0]
        zone_y  = uy + uh * z[0]
        zone_h  = uh * (z[1] - z[0])
        self._telem_card(c, lx, zone_y, col_w, zone_h,
                         f"{self.state.x_m:.2f} m", "Pos. X", "#c8dde9", 12)
        self._telem_card(c, rx, zone_y, col_w, zone_h,
                         f"{self.state.y_m:.2f} m", "Pos. Y", "#c8dde9", 12)
        c.create_line(cx, zone_y + zone_h * 0.15, cx, zone_y + zone_h * 0.85, fill="#162432", width=3)
        c.create_line(x + PAD, uy + uh * z[1], x + w - PAD, uy + uh * z[1], fill="#162432", width=3)

        # ── Rangée 2 : Vitesse | Cap ──
        z = zones[1]
        zone_y  = uy + uh * z[0]
        zone_h  = uh * (z[1] - z[0])
        self._telem_card(c, lx, zone_y, col_w, zone_h,
                         f"{speed:.2f} m/s", "Vitesse", "#ffd166", 13)
        self._telem_card(c, rx, zone_y, col_w, zone_h,
                         f"{self.state.heading_deg:.1f}°", "Cap", "#c8dde9", 13)
        c.create_line(cx, zone_y + zone_h * 0.15, cx, zone_y + zone_h * 0.85, fill="#162432", width=3)
        c.create_line(x + PAD, uy + uh * z[1], x + w - PAD, uy + uh * z[1], fill="#162432", width=3)

        # ── Rangée 3 : Balles | Batterie ──
        z = zones[2]
        zone_y  = uy + uh * z[0]
        zone_h  = uh * (z[1] - z[0])
        bat     = self.state.battery_pct
        bat_col = "#2ecc71" if bat > 40 else ("#f39c12" if bat > 15 else "#e74c3c")
        self._telem_card(c, lx, zone_y, col_w, zone_h,
                         str(self.state.balls_stored), "Balles", "#2ecc71", 15)
        # Batterie : valeur+label centrés, barre en dessous dans la zone
        self._telem_card(c, rx, zone_y, col_w, zone_h,
                         f"{bat:.0f} %", "Batterie", bat_col, 13)
        c.create_line(cx, zone_y + zone_h * 0.15, cx, zone_y + zone_h * 0.85, fill="#162432", width=3)
        # Barre batterie positionnée dans le bas de la zone
        bw      = col_w - 8
        bh_     = 6
        bbar_x  = rx + 4
        bbar_y  = zone_y + zone_h - 14
        fill_w  = int(bw * bat / 100)
        c.create_rectangle(bbar_x, bbar_y, bbar_x + bw, bbar_y + bh_,
                           fill="#1a2a35", outline="#2e4050")
        if fill_w > 0:
            c.create_rectangle(bbar_x, bbar_y, bbar_x + fill_w, bbar_y + bh_,
                               fill=bat_col, outline="")
        c.create_line(x + PAD, uy + uh * z[1], x + w - PAD, uy + uh * z[1], fill="#162432", width=3)

        # ── Rangée 4 : Source ──
        z = zones[3]
        zone_y  = uy + uh * z[0]
        zone_h  = uh * (z[1] - z[0])
        src_col = "#2ecc71" if self.state.connection_ok else "#e74c3c"
        dot_r   = 4
        label   = self.state.source_label
        total_w = dot_r * 2 + 6 + len(label) * 7
        dot_cx  = cx - total_w / 2 + dot_r
        mid_y   = zone_y + zone_h / 2
        c.create_oval(dot_cx - dot_r, mid_y - dot_r,
                      dot_cx + dot_r, mid_y + dot_r,
                      fill=src_col, outline="")
        c.create_text(dot_cx + dot_r + 6, mid_y, anchor="w",
                      text=label, fill="#8ab5cc", font=("Helvetica", 9))

        c.create_line(x, y + h - 1, x + w, y + h - 1, fill="#1e3040", width=3)

    def _telem_card(self, c, x, y, w, zone_h, value, label, val_color, val_size):
        """Valeur + label centrés verticalement dans la zone donnée."""
        cx        = x + w / 2
        block_h   = val_size + 5 + 11   # valeur + espacement + label (font 8 ≈ 11px)
        start_y   = y + (zone_h - block_h) / 2
        c.create_text(cx, start_y, anchor="n",
                      text=value, fill=val_color, font=("Helvetica", val_size, "bold"))
        c.create_text(cx, start_y + val_size + 5, anchor="n",
                      text=label, fill="#3d6d88", font=("Helvetica", 8))

    def _draw_robot_view(self, c, x, y, w, h):
        c.create_rectangle(x, y, x + w, y + h, fill="#0e1419", outline="")
        # Titre
        c.create_rectangle(x, y, x + w, y + 26, fill="#0d1820", outline="")
        c.create_text(x + w / 2, y + 13, anchor="center",
                      text="Vue locale", fill="#7ec8e3", font=("Helvetica", 10, "bold"))

        cx = x + w / 2
        cy = y + h / 2
        meters_span = 10.0
        px_per_m = min(w, h) / meters_span

        # Grille
        for i in range(-int(meters_span / 2), int(meters_span / 2) + 1):
            gx = cx + i * px_per_m
            gy = cy + i * px_per_m
            c.create_line(gx, y, gx, y + h, fill="#1a2530")
            c.create_line(x, gy, x + w, gy, fill="#1a2530")

        # Anneaux de distance
        for dist in [1, 2, 3, 4]:
            r = dist * px_per_m
            c.create_oval(cx - r, cy - r, cx + r, cy + r, outline="#2a3d4a", width=1)
            c.create_text(cx + 6, cy - r - 7, anchor="nw",
                          text=f"{dist} m", fill="#7a9aab", font=("Helvetica", 9))

        # Faisceaux capteurs
        self._draw_sensor_beams(c, cx, cy, px_per_m)

        # Carré robot
        size_px = ROBOT_SIZE_M * px_per_m
        half = size_px / 2
        c.create_rectangle(cx - half, cy - half, cx + half, cy + half,
                           fill="#34495e", outline="#ecf0f1", width=2)
        c.create_line(cx, cy, cx, cy - size_px * 1.4,
                     fill="#ffd166", width=3, arrow="last")


        # Légende couleurs
        leg_y = y + h - 22
        for i, (label, col) in enumerate([("< 1 m", "#e74c3c"), ("1–4 m", "#f39c12"), ("> 4 m", "#2ecc71")]):
            lx = cx - 140 + i * 110
            c.create_rectangle(lx, leg_y, lx + 14, leg_y + 14, fill=col, outline="")
            c.create_text(lx + 20, leg_y + 7, anchor="w",
                         text=label, fill="#dce9f0", font=("Helvetica", 9, "bold"))

    def _draw_sensor_beams(self, c, cx, cy, px_per_m):
        for sensor in ULTRASONIC_SENSORS:
            dist  = float(self.state.sensor_distances_m.get(sensor["name"], 5.0))
            color = self._dist_color(dist)
            angle = math.radians(sensor["angle_deg"])
            ex = cx + math.sin(angle) * dist * px_per_m
            ey = cy - math.cos(angle) * dist * px_per_m
            c.create_line(cx, cy, ex, ey, fill=color, width=3)
            c.create_oval(ex - 5, ey - 5, ex + 5, ey + 5, fill=color, outline="")

    # ------------------------------------------------------------------
    # Vue terrain
    # ------------------------------------------------------------------
    def _update_map(self):
        """Met à jour l'occupancy map à partir des capteurs ultrasons."""
        rx, ry  = self.state.x_m, self.state.y_m
        heading = self.state.heading_deg

        # Trajet robot
        if (not self._robot_trail or
                math.hypot(rx - self._robot_trail[-1][0],
                           ry - self._robot_trail[-1][1]) > 0.10):
            self._robot_trail.append((rx, ry))
            if len(self._robot_trail) > 3000:
                self._robot_trail.pop(0)

        # Pour chaque capteur : marquer la cellule de l'obstacle détecté
        for sensor in ULTRASONIC_SENSORS:
            dist = self.state.sensor_distances_m.get(sensor["name"], 5.0)
            if dist >= 5.0:
                continue
            angle_abs = math.radians(sensor["angle_deg"] + heading)
            ox = rx + math.sin(angle_abs) * dist
            oy = ry - math.cos(angle_abs) * dist
            col, row = self._world_to_cell(ox, oy)
            if 0 <= row < self._map_rows and 0 <= col < self._map_cols:
                prev = self._occ_map[row][col]
                # Garder la distance minimale de détection
                if prev < 0 or dist < prev:
                    self._occ_map[row][col] = dist

    def _world_to_cell(self, wx, wy):
        """Convertit des coordonnées monde (m) en indices (col, row) de la grille."""
        col = int((wx + self.MAP_MARGIN) / self.MAP_RES)
        row = int((wy + self.MAP_MARGIN) / self.MAP_RES)
        return col, row

    def _cell_to_world(self, col, row):
        """Centre d'une cellule en coordonnées monde (m)."""
        wx = col * self.MAP_RES - self.MAP_MARGIN + self.MAP_RES / 2
        wy = row * self.MAP_RES - self.MAP_MARGIN + self.MAP_RES / 2
        return wx, wy

    def _draw_court_view(self, c, x, y, w, h):
        # Fond noir — terrain inconnu
        c.create_rectangle(x, y, x + w, y + h, fill="#080d0a", outline="")

        # Titre avec dégradé : #1a3a50 -> #080d0a
        _th = 26
        _r1,_g1,_b1 = 0x1a,0x3a,0x50
        _r2,_g2,_b2 = 0x08,0x0d,0x0a
        for _i in range(_th):
            _t = _i / max(1, _th - 1)
            _r = int(_r1 + (_r2-_r1)*_t)
            _g = int(_g1 + (_g2-_g1)*_t)
            _b = int(_b1 + (_b2-_b1)*_t)
            c.create_line(x, y+_i, x+w, y+_i, fill=f"#{_r:02x}{_g:02x}{_b:02x}")
        c.create_text(x + w / 2, y + 13, anchor="center",
                      text="Vue terrain", fill="#7ec8e3", font=("Helvetica", 10, "bold"))

        TITLE_H = 26
        draw_y  = y + TITLE_H
        draw_h  = h - TITLE_H

        margin = min(w * 0.07, draw_h * 0.05)
        scale  = min((w - 2*margin) / COURT_WIDTH_M, (draw_h - 2*margin) / COURT_LENGTH_M)
        cw     = COURT_WIDTH_M  * scale
        ch_    = COURT_LENGTH_M * scale
        ox     = x + (w  - cw)  / 2
        oy     = draw_y + (draw_h - ch_) / 2

        def m2px(mx, my):
            return ox + mx * scale, oy + my * scale

        # ── Occupancy map : dessiner les cellules occupées ──
        # 4 paliers de couleur selon distance de détection :
        # < 0.5 m → très clair  #a8e6cf
        # 0.5–1.5 m → clair     #52b788
        # 1.5–3.0 m → moyen     #2d6a4f
        # 3.0–5.0 m → foncé     #1b4332
        DIST_COLORS = [
            (0.5,  "#a8e6cf"),
            (1.5,  "#52b788"),
            (3.0,  "#2d6a4f"),
            (5.0,  "#1b4332"),
        ]
        cell_px = max(1, self.MAP_RES * scale)
        for row in range(self._map_rows):
            for col in range(self._map_cols):
                dist_val = self._occ_map[row][col]
                if dist_val < 0:
                    continue
                wx, wy = self._cell_to_world(col, row)
                px, py = m2px(wx, wy)
                color = DIST_COLORS[-1][1]
                for threshold, col_hex in DIST_COLORS:
                    if dist_val < threshold:
                        color = col_hex
                        break
                c.create_rectangle(px, py, px + cell_px, py + cell_px,
                                   fill=color, outline="")

        # ── Trajet robot ──
        if len(self._robot_trail) > 1:
            trail_pts = []
            for (tx, ty) in self._robot_trail:
                px, py = m2px(tx, ty)
                trail_pts.extend([px, py])
            if len(trail_pts) >= 4:
                c.create_line(*trail_pts, fill="#1a4a30", width=2, smooth=True)

        self._draw_robot_on_court(c, ox, oy, scale)

    def _draw_robot_on_court(self, c, ox, oy, scale):
        cx    = ox + self.state.x_m * scale
        cy    = oy + self.state.y_m * scale
        size  = ROBOT_SIZE_M * scale
        half  = size / 2
        angle = math.radians(self.state.heading_deg)
        speed = math.hypot(self.state.vx_mps, self.state.vy_mps)

        def rpt(lx, ly):
            rx, ry = self._rot(lx, ly, angle)
            return cx + rx, cy + ry

        # Ombre portée (décalage léger)
        shadow_off = max(2, size * 0.12)
        shadow_pts = []
        for lx, ly in [(-half, -half), (half, -half), (half, half), (-half, half)]:
            rx, ry = self._rot(lx, ly, angle)
            shadow_pts.extend([cx + rx + shadow_off, cy + ry + shadow_off])
        c.create_polygon(shadow_pts, fill="#0a0e12", outline="", stipple="gray50")

        # Corps principal
        body_pts = []
        for lx, ly in [(-half, -half), (half, -half), (half, half), (-half, half)]:
            bx, by = rpt(lx, ly)
            body_pts.extend([bx, by])
        c.create_polygon(body_pts, fill="#1e3a52", outline="#5da8c8", width=2)

        # Panneau avant coloré (bande sur le tiers avant)
        front_half = half * 0.35
        front_pts = []
        for lx, ly in [(-half, -half), (half, -half), (half, -half + front_half*2), (-half, -half + front_half*2)]:
            bx, by = rpt(lx, ly)
            front_pts.extend([bx, by])
        c.create_polygon(front_pts, fill="#2980b9", outline="")

        # 4 roues (petits rectangles aux coins)
        wheel_w, wheel_h = size * 0.18, size * 0.32
        for wx, wy in [(-half - wheel_w*0.4,  -half + size*0.15),
                       ( half - wheel_w*0.6,  -half + size*0.15),
                       (-half - wheel_w*0.4,   half - size*0.47),
                       ( half - wheel_w*0.6,   half - size*0.47)]:
            wp = []
            for lx, ly in [(wx, wy), (wx+wheel_w, wy), (wx+wheel_w, wy+wheel_h), (wx, wy+wheel_h)]:
                bx, by = rpt(lx, ly)
                wp.extend([bx, by])
            c.create_polygon(wp, fill="#101820", outline="#3a5a70", width=1)

        # Point central
        c.create_oval(cx-3, cy-3, cx+3, cy+3, fill="#e8f0f5", outline="")

        # Flèche de cap
        arr_len = max(size * 1.5, 18)
        tip_x = cx + math.sin(angle) * arr_len
        tip_y = cy - math.cos(angle) * arr_len
        c.create_line(cx, cy, tip_x, tip_y, fill="#ffd166", width=3, arrow="last")

        # Halo vitesse (cercle dont le rayon dépend de la vitesse)
        if speed > 0.05:
            halo_r = max(half * 1.3, half * 1.3 + speed * scale * 0.15)
            c.create_oval(cx - halo_r, cy - halo_r, cx + halo_r, cy + halo_r,
                          outline="#886622" if speed < 0.5 else "#ffd166",
                          width=1, dash=(4, 4))

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------
    @staticmethod
    def _rot(x, y, a):
        return x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)

    @staticmethod
    def _dist_color(d):
        if d < 1.0: return "#e74c3c"
        if d > 4.0: return "#2ecc71"
        return "#f39c12"


def main():
    root = tk.Tk()
    app  = TennisRobotUI(root, DataAdapter(MAC_BLE_ROBOT))
    root.protocol("WM_DELETE_WINDOW", lambda: (setattr(app, "running", False), root.destroy()))
    root.mainloop()


if __name__ == "__main__":
    main()
