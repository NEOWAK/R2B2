import serial
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from collections import deque

PORT     = "COM10"       # ou "/dev/ttyUSB0" sous Linux
BAUD     = 115200
MAX_PTS  = 1000          # nombre de points affichés

adc0 = deque([0] * MAX_PTS, maxlen=MAX_PTS)
adc1 = deque([0] * MAX_PTS, maxlen=MAX_PTS)

ser = serial.Serial(PORT, BAUD, timeout=1)

fig, ax = plt.subplots()
line0, = ax.plot([], [], label="ADC0")
line1, = ax.plot([], [], label="ADC1")
ax.set_ylim(0, 4095)
ax.set_xlim(0, MAX_PTS)
ax.legend()

def update(frame):
    while ser.in_waiting:
        line = ser.readline().decode("utf-8").strip()
        if "," in line:
            ch, val = line.split(",")
            if ch == "0":   adc0.append(int(val))
            elif ch == "1": 
                adc1.append(int(val))
                print( val )
                
    line0.set_data(range(MAX_PTS), adc0)
    line1.set_data(range(MAX_PTS), adc1)
    return line0, line1

ani = animation.FuncAnimation(fig, update, interval=50, blit=True)
plt.show()