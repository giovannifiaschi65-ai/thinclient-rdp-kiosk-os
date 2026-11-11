#!/usr/bin/env python3
"""Genera il tema Plymouth animato 'rdp-kiosk' (logo + spinner 24 frame + testi IT)."""

import math
import os
import sys
import cairo


def draw_rounded_rect(ctx: cairo.Context, x: float, y: float, w: float, h: float, r: float) -> None:
    ctx.new_sub_path()
    ctx.arc(x + w - r, y + r, r, -math.pi / 2, 0)
    ctx.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
    ctx.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
    ctx.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
    ctx.close_path()


def generate_logo(out_dir: str, build_ver: str = "") -> None:
    w, h = 440, 176
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
    ctx = cairo.Context(surf)
    cx = w / 2.0

    # Bagliore radiale morbido dietro l'icona monitor
    glow = cairo.RadialGradient(cx, 54, 6, cx, 54, 64)
    glow.add_color_stop_rgba(0.0, 0.220, 0.741, 0.973, 0.24)
    glow.add_color_stop_rgba(1.0, 0.220, 0.741, 0.973, 0.0)
    ctx.set_source(glow)
    ctx.arc(cx, 54, 64, 0, 2 * math.pi)
    ctx.fill()

    # Schermo monitor Thin Client
    mw, mh = 80.0, 52.0
    mx, my = cx - mw / 2.0, 22.0
    draw_rounded_rect(ctx, mx, my, mw, mh, 9.0)
    ctx.set_source_rgba(0.118, 0.161, 0.231, 0.95)  # #1e293b
    ctx.fill_preserve()
    ctx.set_line_width(3.2)
    ctx.set_source_rgba(0.220, 0.741, 0.973, 1.0)  # #38bdf8
    ctx.stroke()

    # Piedistallo e base monitor
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    ctx.set_line_width(3.2)
    ctx.set_source_rgba(0.376, 0.647, 0.980, 0.95)  # #60a5fa
    ctx.move_to(cx, my + mh + 1)
    ctx.line_to(cx, my + mh + 11)
    ctx.stroke()

    ctx.move_to(cx - 18, my + mh + 12)
    ctx.line_to(cx + 18, my + mh + 12)
    ctx.stroke()

    # Simbolo interno connessione RDP (freccia chevron + nodo remoto)
    ctx.set_line_width(3.0)
    ctx.set_line_join(cairo.LINE_JOIN_ROUND)
    ctx.set_source_rgba(0.973, 0.980, 0.988, 0.96)
    ctx.move_to(cx - 16, my + 17)
    ctx.line_to(cx - 5, my + mh / 2.0)
    ctx.line_to(cx - 16, my + mh - 17)
    ctx.stroke()

    ctx.set_source_rgba(0.220, 0.741, 0.973, 1.0)
    ctx.move_to(cx + 3, my + mh / 2.0)
    ctx.line_to(cx + 15, my + mh / 2.0)
    ctx.stroke()
    ctx.arc(cx + 19, my + mh / 2.0, 3.2, 0, 2 * math.pi)
    ctx.fill()

    # Titolo principale "Thin Client RDP"
    ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
    ctx.set_font_size(27.0)
    title = "Thin Client RDP"
    ext = ctx.text_extents(title)
    ctx.set_source_rgba(0.973, 0.980, 0.988, 1.0)  # #f8fafc
    ctx.move_to(cx - (ext.width / 2.0 + ext.x_bearing), 132.0)
    ctx.show_text(title)

    # Sottotitolo con versione YYMMDDHHMM
    ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
    ctx.set_font_size(12.0)
    sub = f"SISTEMA OPERATIVO KIOSK  •  {build_ver}" if build_ver else "SISTEMA OPERATIVO KIOSK"
    ext_s = ctx.text_extents(sub)
    ctx.set_source_rgba(0.580, 0.639, 0.722, 0.92)  # #94a3b8
    ctx.move_to(cx - (ext_s.width / 2.0 + ext_s.x_bearing), 156.0)
    ctx.show_text(sub)

    surf.write_to_png(os.path.join(out_dir, "logo.png"))


def generate_spinner_frames(out_dir: str, num_frames: int = 24) -> None:
    size = 68
    cx = cy = size / 2.0
    radius = 23.0

    for frame in range(num_frames):
        surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, size, size)
        ctx = cairo.Context(surf)

        # Traccia circolare di fondo
        ctx.set_line_width(4.5)
        ctx.set_source_rgba(0.580, 0.639, 0.722, 0.16)
        ctx.arc(cx, cy, radius, 0, 2 * math.pi)
        ctx.stroke()

        # Arco luminoso rotante a scia morbida
        head_angle = (2.0 * math.pi * frame / num_frames) - (math.pi / 2.0)
        segments = 18
        arc_span = 1.45 * math.pi
        step = arc_span / segments

        ctx.set_line_cap(cairo.LINE_CAP_ROUND)
        ctx.set_line_width(4.5)
        for s in range(segments):
            frac = (s + 1) / segments
            a0 = head_angle - arc_span + s * step
            a1 = a0 + step * 1.15
            # Gradiente da blu intenso (#2563eb) a ciano brillante (#38bdf8 -> #bae6fd)
            r = 0.145 * (1.0 - frac) + 0.350 * frac
            g = 0.388 * (1.0 - frac) + 0.780 * frac
            b = 0.922 * (1.0 - frac) + 0.985 * frac
            alpha = 0.06 + 0.94 * (frac ** 1.7)
            ctx.set_source_rgba(r, g, b, alpha)
            ctx.arc(cx, cy, radius, a0, a1)
            ctx.stroke()

        # Punto luminoso in testa all'arco
        hx = cx + radius * math.cos(head_angle)
        hy = cy + radius * math.sin(head_angle)
        tip_glow = cairo.RadialGradient(hx, hy, 1.0, hx, hy, 8.0)
        tip_glow.add_color_stop_rgba(0.0, 0.729, 0.902, 0.992, 0.95)
        tip_glow.add_color_stop_rgba(1.0, 0.220, 0.741, 0.973, 0.0)
        ctx.set_source(tip_glow)
        ctx.arc(hx, hy, 8.0, 0, 2 * math.pi)
        ctx.fill()

        surf.write_to_png(os.path.join(out_dir, f"spinner_{frame}.png"))


def generate_caption(out_dir: str, filename: str, text: str) -> None:
    w, h = 420, 36
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
    ctx = cairo.Context(surf)
    ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
    ctx.set_font_size(15.0)
    ext = ctx.text_extents(text)
    ctx.set_source_rgba(0.796, 0.835, 0.882, 0.92)  # #cbd5e1
    ctx.move_to((w / 2.0) - (ext.width / 2.0 + ext.x_bearing), 23.0)
    ctx.show_text(text)
    surf.write_to_png(os.path.join(out_dir, filename))


def write_plymouth_files(out_dir: str) -> None:
    plymouth_ini = """[Plymouth Theme]
Name=Thin Client RDP
Description=Tema di avvio animato Thin Client RDP Kiosk
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/rdp-kiosk
ScriptFile=/usr/share/plymouth/themes/rdp-kiosk/rdp-kiosk.script
"""
    script_code = """// Sfondo coordinato con l'interfaccia Kiosk (#0f172a)
Window.SetBackgroundTopColor(0.059, 0.090, 0.165);
Window.SetBackgroundBottomColor(0.039, 0.063, 0.122);

screen_w = Window.GetWidth();
screen_h = Window.GetHeight();
screen_x = Window.GetX();
screen_y = Window.GetY();

logo_img = Image("logo.png");
logo_sprite = Sprite(logo_img);
logo_x = screen_x + (screen_w / 2) - (logo_img.GetWidth() / 2);
logo_y = screen_y + (screen_h / 2) - (logo_img.GetHeight() / 2) - 52;
logo_sprite.SetPosition(logo_x, logo_y, 10);

for (i = 0; i < 24; i++) {
    spinner_imgs[i] = Image("spinner_" + i + ".png");
}
spinner_sprite = Sprite(spinner_imgs[0]);
spinner_x = screen_x + (screen_w / 2) - (spinner_imgs[0].GetWidth() / 2);
spinner_y = logo_y + logo_img.GetHeight() + 14;
spinner_sprite.SetPosition(spinner_x, spinner_y, 10);

mode = Plymouth.GetMode();
if (mode == "shutdown" || mode == "poweroff" || mode == "halt") {
    msg_img = Image("msg_shutdown.png");
} else if (mode == "reboot") {
    msg_img = Image("msg_reboot.png");
} else {
    msg_img = Image("msg_boot.png");
}
msg_sprite = Sprite(msg_img);
msg_x = screen_x + (screen_w / 2) - (msg_img.GetWidth() / 2);
msg_y = spinner_y + spinner_imgs[0].GetHeight() + 14;
msg_sprite.SetPosition(msg_x, msg_y, 10);

tick = 0;
fun refresh_callback() {
    tick++;
    frame = Math.Int(tick / 2) % 24;
    spinner_sprite.SetImage(spinner_imgs[frame]);
    pulse = 0.93 + 0.07 * Math.Sin(tick * 0.08);
    logo_sprite.SetOpacity(pulse);
}
Plymouth.SetRefreshFunction(refresh_callback);
"""
    with open(os.path.join(out_dir, "rdp-kiosk.plymouth"), "w", encoding="utf-8", newline="\n") as f:
        f.write(plymouth_ini)
    with open(os.path.join(out_dir, "rdp-kiosk.script"), "w", encoding="utf-8", newline="\n") as f:
        f.write(script_code)


def main() -> None:
    target_dir = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/plymouth/themes/rdp-kiosk"
    build_ver = sys.argv[2].strip() if len(sys.argv) > 2 else ""
    os.makedirs(target_dir, exist_ok=True)
    generate_logo(target_dir, build_ver)
    generate_spinner_frames(target_dir, 24)
    generate_caption(target_dir, "msg_boot.png", "Avvio del sistema in corso...")
    generate_caption(target_dir, "msg_shutdown.png", "Spegnimento del sistema in corso...")
    generate_caption(target_dir, "msg_reboot.png", "Riavvio del sistema in corso...")
    write_plymouth_files(target_dir)


if __name__ == "__main__":
    main()
