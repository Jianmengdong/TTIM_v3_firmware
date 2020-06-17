from TTIM_v2 import *
from time import sleep
# import matplotlib as mp
# mp.use("Agg")
# import matplotlib.pyplot as plt


print("----------Eye scan - Demonstration script----------------")
# ttim_ip = "192.168.10.11"
ttim = TTIM()
x1 = []
list1 = []
ch = int(input("channel to run eye scan(1 - 48): ")) - 1
test_mode = ttim.get("test_mode") | (1 << ch)
ttim.set("test_mode", test_mode)
ttim.set("channel_sel", ch)
ttim.set("load_tap", 0)
# sel = input("1 -> RX1\n2 -> RX2\n")
print("eye scan start...")
j = 0
eye_width1 = 0
eye_width2 = 0
edge1 = 0
edge2 = 0
eye_stop = 0
print("tap_cnt    error")
# if sel == "1":
while j < 63:
    # err_cnt1 = ttim.get("tap_err_cnt")
    ttim.set("tap_cnt", j)
    ttim.set("load_tap", 1)
    ttim.set("load_tap", 0)
    ttim.set("inject_reset", 1)
    ttim.set("inject_reset", 0)
    sleep(0.2)
    # err_cnt2 = ttim.get("tap_err_cnt")
    # err_cnt = err_cnt2 - err_cnt1
    err_cnt = ttim.get("error_cnt1")
    print("%d    %d" % (j, err_cnt))
    if err_cnt <= 50:
        edge2 = j
        eye_width2 = eye_width2 + 1
        if eye_stop == 0:
            edge1 = j
            eye_width1 = eye_width1 + 1
    else:
        eye_stop = 1
        eye_width2 = 0

    if err_cnt > 2000:
        err_cnt = 2000
    x1.append(j)
    list1.append(err_cnt)
    j = j + 1
if eye_width1 >= eye_width2:
    tap_cnt = edge1 - eye_width1//2
else:
    tap_cnt = edge2 - eye_width2//2
ttim.set("tap_cnt", tap_cnt)
ttim.set("load_tap", 1)
ttim.set("load_tap", 0)
print("RX1 tap_cnt set to %d" % tap_cnt)
ttim.set("inject_reset", 1)
ttim.set("inject_reset", 0)

j = 0
eye_width1 = 0
eye_width2 = 0
edge1 = 0
edge2 = 0
eye_stop = 0
# elif sel == "2":
while j < 63:
    # err_cnt1 = ttim.get("tap_err_cnt")
    ttim.set("tap_cnt", j)
    ttim.set("load_tap", 2)
    ttim.set("load_tap", 0)
    ttim.set("inject_reset", 1)
    ttim.set("inject_reset", 0)
    sleep(0.2)
    # err_cnt2 = ttim.get("tap_err_cnt")
    # err_cnt = err_cnt2 - err_cnt1
    err_cnt = ttim.get("error_cnt2")
    print("%d    %d" % (j, err_cnt))
    if err_cnt <= 50:
        edge2 = j
        eye_width2 = eye_width2 + 1
        if eye_stop == 0:
            edge1 = j
            eye_width1 = eye_width1 + 1
    else:
        eye_stop = 1
        eye_width2 = 0
    if err_cnt > 2000:
        err_cnt = 2000
    x1.append(j)
    list1.append(err_cnt)
    j = j + 1
if eye_width1 >= eye_width2:
    tap_cnt = edge1 - eye_width1//2
else:
    tap_cnt = edge2 - eye_width2//2
ttim.set("tap_cnt", tap_cnt)
ttim.set("load_tap", 2)
ttim.set("load_tap", 0)
print("RX2 tap_cnt set to %d" % tap_cnt)
ttim.set("inject_reset", 1)
ttim.set("inject_reset", 0)
# plt.figure(1)
# plt.title("eye scan result")
# plt.xlabel("tap count")
# plt.ylabel("error count")
# plt.plot(x1, list1, "ro")
# plt.show()
# plt.savefig("eye.png", format="png")
print("eye scan stop")
