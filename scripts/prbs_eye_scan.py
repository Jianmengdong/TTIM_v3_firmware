from TTIM_tools import *
from time import sleep
import os
# import matplotlib as mp
# mp.use("Agg")
# import matplotlib.pyplot as plt


def main():
    f = open(os.path.dirname(os.path.abspath(__file__)) + "/TTIM_ip.dat")
    host_ip = f.readline().strip()
    f.close()
    reg = os.path.dirname(os.path.abspath(__file__)) + "/TTIM_v2_registers.dat"
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("", 2000))
    sock.settimeout(2)
    ttim = TTIM(host_ip, reg, sock)
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
