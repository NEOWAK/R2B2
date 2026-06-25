import serial
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import matplotlib.widgets as widgets
from collections import deque

PORT     = "COM10"       # ou "/dev/ttyUSB0" sous Linux
BAUD     = 115200
MAX_PTS  = 1000

adc0 = deque([0] * MAX_PTS, maxlen=MAX_PTS)
adc1 = deque([0] * MAX_PTS, maxlen=MAX_PTS)

ser = serial.Serial(PORT, BAUD, timeout=1)

fig, ax = plt.subplots()
plt.subplots_adjust(bottom=0.15)

line0, = ax.plot([], [], label="ADC0")
line1, = ax.plot([], [], label="ADC1")
ax.set_ylim(0, 4095)
ax.set_xlim(0, MAX_PTS)
ax.legend()

ax_btn = plt.axes([0.45, 0.02, 0.12, 0.06])
btn_pause = widgets.Button(ax_btn, 'Pause')

paused = False

def toggle_pause(event):
    global paused
    paused = not paused
    btn_pause.label.set_text('Reprendre' if paused else 'Pause')
    if not paused:
        ser.reset_input_buffer()  # Vide le buffer accumulé pendant la pause
    fig.canvas.draw_idle()

btn_pause.on_clicked(toggle_pause)

def update(frame):
    if paused:
        ser.reset_input_buffer()  # Vide en continu pour ne pas accumuler
        return line0, line1

    while ser.in_waiting:
        raw = ser.readline().decode("utf-8").strip()
        if "," in raw:
            ch, val = raw.split(",")
            if ch == "0":
                adc0.append(int(val))
            elif ch == "1":
                adc1.append(int(val))
                print(val)

    line0.set_data(range(MAX_PTS), adc0)
    line1.set_data(range(MAX_PTS), adc1)
    return line0, line1

ani = animation.FuncAnimation(fig, update, interval=50, blit=True)
plt.show()