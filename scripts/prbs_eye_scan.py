from TTIM_v2 import *
from time import sleep
import os
# import matplotlib as mp
# mp.use("Agg")
# import matplotlib.pyplot as plt


def calibrate_rx(ttim, channel, pair, show=False):
    ttim.set("channel_sel", channel)
    ttim.set("load_tap", 0)
    j = 0
    eye_width1 = 0
    eye_width2 = 0
    edge1 = 0
    edge2 = 0
    eye_stop = 0
    points = []
    x = []
    y = []
    error_cnt = "error_cnt" + str(pair)
    if show is True:
        print("tap_cnt    error")
    # if sel == "1":
    while j < 63:
        # err_cnt1 = ttim.get("tap_err_cnt")
        ttim.set("tap_cnt", j)
        ttim.set("load_tap", pair)
        ttim.set("load_tap", 0)
        ttim.set("inject_reset", 1)
        ttim.set("inject_reset", 0)
        sleep(0.01)
        # err_cnt2 = ttim.get("tap_err_cnt")
        # err_cnt = err_cnt2 - err_cnt1
        err_cnt = ttim.get(error_cnt)
        if show is True:
            print("%d    %d" % (j, err_cnt))
        if err_cnt <= 50:
            points.append(j)
        #     edge2 = j
        #     eye_width2 = eye_width2 + 1
        #     if eye_stop == 0:
        #         edge1 = j
        #         eye_width1 = eye_width1 + 1
        # else:
        #     eye_stop = 1
        #     eye_width2 = 0

        if err_cnt > 2000:
            err_cnt = 2000
        x.append(j)
        y.append(err_cnt)
        j = j + 1
    # print(points)
    i = 0
    edge = []  # eye edge list
    eye = 1
    while i < len(points):
        if i + 1 == len(points):
            edge.append((points[i + 1 - eye], points[i]))
        elif points[i+1] - points[i] == 1:  # consecutive tap means inside eye
            eye += 1
        else:
            edge.append((points[i+1-eye], points[i]))
            eye = 1
        i += 1
    # print(edge)
    tap_cnt = (edge[0][0] + edge[0][1]) // 2
    eye = edge[0][1] - edge[0][0]
    for i in range(len(edge) - 1):
        eye2 = edge[i+1][1] - edge[i+1][0]
        if eye2 > eye:
            eye = eye2
            tap_cnt = (edge[i+1][0] + edge[i+1][1]) // 2
    # if eye_width1 >= eye_width2:
    #     tap_cnt = edge1 - eye_width1 // 2
    # else:
    #     tap_cnt = edge2 - eye_width2 // 2
    ttim.set("tap_cnt", tap_cnt)
    ttim.set("load_tap", pair)
    ttim.set("load_tap", 0)
    ttim.set("inject_reset", 1)
    ttim.set("inject_reset", 0)
    return tap_cnt, x, y


def main():
    f = open(os.path.dirname(os.path.abspath(__file__)) + "/TTIM_ip.dat")
    host_ip = f.readline().strip()
    f.close()
    ttim = TTIM(host_ip)
    print("----------Eye scan - Demonstration script----------------")
    # ttim_ip = "192.168.10.11"
    ch = int(input("channel to run eye scan(1 - 48): ")) - 1
    test_mode = ttim.get("test_mode") | (1 << ch)
    ttim.set("test_mode", test_mode)
    ttim.set("loop_test", 1)  # when use test_base to do loop_test
    # sel = input("1 -> RX1\n2 -> RX2\n")
    print("eye scan start...")
    tap_cnt, x1, y1 = calibrate_rx(ttim, ch, 1, True)
    print("RX1 tap_cnt set to %d" % tap_cnt)
    tap_cnt, x2, y2 = calibrate_rx(ttim, ch, 2, True)
    print("RX2 tap_cnt set to %d" % tap_cnt)
    # plt.figure(1)
    # plt.title("eye scan result")
    # plt.xlabel("tap count")
    # plt.ylabel("error count")
    # plt.plot(x1, list1, "ro")
    # plt.show()
    # plt.savefig("eye.png", format="png")
    print("eye scan stop")


if __name__ == "__main__":
    main()
