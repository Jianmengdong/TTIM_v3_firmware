from TTIM_v2 import *
from time import sleep
# import matplotlib as mp
# mp.use("Agg")
import matplotlib.pyplot as plt


print("----------Eye scan - Demonstration script----------------")
# ttim_ip = "192.168.10.11"
ttim = TTIM()
x1 = []
list1 = []
ch = int(input("channel to run eye scan(1 - 48): ")) - 1
ttim.set("channel_sel", ch)
test_mode_orig = ttim.get("test_mode")
print(test_mode_orig)
test_mode = test_mode_orig >> (ch + 1) << (ch + 1) | (test_mode_orig << (48 - ch) >> (48 - ch))
print(test_mode)
ttim.set("test_mode", 0)
sel = input("1 -> TTC\n2 -> L1A\n")
print("eye scan start...")
j = 1
print("tap_cnt    error")
if sel == "1":
    ttim.set("tap_rst", 1)
    ttim.set("tap_rst", 0)
    ttim.set("inject_reset", 1)
    ttim.set("inject_reset", 0)
    while j < 123:
        # err_cnt1 = ttim.get("tap_err_cnt")
        ttim.set("tap_incr", 2)
        ttim.set("tap_incr", 0)
        sleep(0.2)
        # err_cnt2 = ttim.get("tap_err_cnt")
        # err_cnt = err_cnt2 - err_cnt1
        err_cnt = ttim.get("tap_err_cnt")
        print("%d    %d" % (j, err_cnt))
        if err_cnt > 2000:
            err_cnt = 2000
        x1.append(j)
        list1.append(err_cnt)
        j = j + 1
elif sel == "2":
    ttim.set("l1a_go_prbs", 1)
    ttim.set("tap_rst", 1)
    ttim.set("tap_rst", 0)
    while j < 123:
        ttim.set("tap_incr", 2)
        ttim.set("tap_incr", 0)
        sleep(0.2)
        err_cnt = ttim.get("tap_err_cnt")
        print("%d    %d" % (j, err_cnt))
        if err_cnt > 2000:
            err_cnt = 2000
        x1.append(j)
        list1.append(err_cnt)
        j = j + 1
    ttim.set("l1a_go_prbs", 0)
plt.figure(1)
plt.title("eye scan result")
plt.xlabel("tap count")
plt.ylabel("error count")
plt.plot(x1, list1, "ro")
plt.show()
plt.savefig("eye.png", format="png")
print("eye scan stop")
