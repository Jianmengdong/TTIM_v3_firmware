from TTIM_v2 import *
from time import sleep
import platform
import argparse
from BEC_timing import calibrate_l1a
from BEC_timing import calibrate_ttc


def main():
    vr = platform.python_version()
    print("Python version is %s" % vr)
    if int(vr.split('.')[0]) != 3:
        print("Please use Python3.x!")
        exit()
    parser = argparse.ArgumentParser(description="set up the GCU mask")
    parser.add_argument("-m", "--mask", dest="mask", type=str, default="0", help="channel mask in HEX")
    parser.add_argument("-t", "--trigger", dest="trigger", type=str, default="0", help="trigger mask in HEX")
    parser.add_argument("-th", "--threshold", dest="threshold", type=str, default="1", help="trigger threshold in HEX")
    parser.add_argument("-p", "--period", dest="period", type=str, default="3b9aca0", help="trigger threshold in HEX")
    result = parser.parse_args()
    mask = int(result.mask, 16)
    threshold = int(result.threshold, 16)
    period = int(result.period, 16)
    trig = int(result.trigger, 16)

    # ttim_ip = "192.168.10.11"
    ttim = TTIM()
    print("*" * 20)
    print("  BEC starting up")
    print("")
    ttim.set("inject_reset", 0)
    print("setting the channel mask...")
    ttim.set("channel_mask", mask)
    sleep(0.1)
    print("setting the trigger threshold...")
    ttim.set("threshold", threshold)
    sleep(0.1)
    print("setting periodic trigger period...")
    ttim.set("trig_period", period)
    sleep(0.1)
    print("setting the trigger mask...")
    ttim.set("en_trig_src", trig)
    sleep(0.1)
    # print("calibrating the channels...")
    ch_cnt = 0
    for ch in range(0, 47):
        not_masked = mask >> ch & 1
        if not_masked == 1:
            ch_cnt = ch_cnt + 1
            print("calibrating TTC channel %d ..." % (ch + 1))
            ttim.set("channel_sel", ch)
            calibrate_ttc(ttim)
            # calibrate_l1a(ttim)
        # else:
            # print("TTC channel %d skipped" % (ch + 1))

    for ch in range(0, 47):
        not_masked = mask >> ch & 1
        if not_masked == 1:
            print("calibrating hit channel %d ..." % (ch + 1))
            ttim.set("channel_sel", ch)
            # calibrate_ttc(ttim)
            calibrate_l1a(ttim)
        # else:
            # print("hit channel %d skipped" % (ch + 1))
    print("")
    print("starting 1588PTP...")
    ttim.set("inject_reset", 4)
    sleep(0.1 * ch_cnt)
    print("BEC started!")


if __name__ == "__main__":
    main()
